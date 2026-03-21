import Foundation
import AVFoundation
import Combine
import Accelerate

/// Plays EMAX II samples pitched across the keyboard using resampling
class InstrumentPlayer: ObservableObject {
    
    private let engine = AVAudioEngine()
    private var playerNodes: [AVAudioPlayerNode] = []
    private var activeNodes: [UInt8: AVAudioPlayerNode] = [:]  // note -> node
    
    @Published var isReady = false
    @Published var activeNote: UInt8? = nil
    @Published var velocity: UInt8 = 127
    @Published var rootKey: UInt8 = 60  // Middle C default
    
    /// The loaded samples mapped by zone
    private var loadedSamples: [LoadedSample] = []
    
    /// Output format (44.1k for quality)
    private let outputRate: Double = 44100
    private let outputFormat: AVAudioFormat
    
    struct LoadedSample {
        let name: String
        let pcmData: Data
        let sampleRate: Int
        let rootKey: Int
        let loopStart: Int?
        let loopEnd: Int?
        var frameCount: Int { pcmData.count / 2 }
    }
    
    // MARK: - Init
    
    init() {
        outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
        
        // 8-voice polyphony
        for _ in 0..<8 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: outputFormat)
            playerNodes.append(node)
        }
        
        do {
            try engine.start()
        } catch {
            print("InstrumentPlayer: engine start failed: \(error)")
        }
    }
    
    deinit {
        stopAll()
        engine.stop()
    }
    
    // MARK: - Load Samples
    
    /// Load samples from BankSampleData
    func loadSamples(from sampleData: BankSampleData) {
        stopAll()
        loadedSamples = sampleData.samples.map { entry in
            LoadedSample(
                name: entry.name,
                pcmData: entry.pcmData,
                sampleRate: entry.sampleRate,
                rootKey: entry.rootKey,
                loopStart: entry.loopStart,
                loopEnd: entry.loopEnd
            )
        }
        
        // Use first sample's root key
        if let first = loadedSamples.first {
            rootKey = UInt8(clamping: first.rootKey)
        }
        
        isReady = !loadedSamples.isEmpty
    }
    
    /// Load a single sample (e.g. when previewing one sample across keyboard)
    func loadSingle(pcmData: Data, sampleRate: Int, rootKey: Int = 60) {
        stopAll()
        loadedSamples = [LoadedSample(
            name: "Sample",
            pcmData: pcmData,
            sampleRate: sampleRate,
            rootKey: rootKey,
            loopStart: nil,
            loopEnd: nil
        )]
        self.rootKey = UInt8(clamping: rootKey)
        isReady = true
    }
    
    // MARK: - Playback
    
    /// Play a MIDI note
    func noteOn(_ note: UInt8, velocity: UInt8 = 127) {
        guard isReady else { return }
        
        // Find best sample for this note (closest root key)
        guard let sample = findSample(for: note) else { return }
        
        // Calculate pitch ratio
        let semitones = Double(Int(note) - sample.rootKey)
        let pitchRatio = pow(2.0, semitones / 12.0)
        
        // Resample PCM data
        guard let buffer = resample(
            pcmData: sample.pcmData,
            sourceSampleRate: Double(sample.sampleRate),
            pitchRatio: pitchRatio,
            volume: Float(velocity) / 127.0
        ) else { return }
        
        // Stop any existing note on this pitch
        noteOff(note)
        
        // Find available node
        guard let node = findAvailableNode() else { return }
        
        activeNodes[note] = node
        activeNote = note
        self.velocity = velocity
        
        if !engine.isRunning {
            try? engine.start()
        }
        
        node.play()
        node.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async {
                self?.activeNodes.removeValue(forKey: note)
                if self?.activeNodes.isEmpty == true {
                    self?.activeNote = nil
                }
            }
        }
    }
    
    /// Stop a specific note
    func noteOff(_ note: UInt8) {
        if let node = activeNodes[note] {
            node.stop()
            // Re-play to reset state
            node.play()
            activeNodes.removeValue(forKey: note)
            if activeNodes.isEmpty {
                activeNote = nil
            }
        }
    }
    
    /// Stop all notes
    func stopAll() {
        for (_, node) in activeNodes {
            node.stop()
        }
        activeNodes.removeAll()
        activeNote = nil
        
        // Reset all nodes
        for node in playerNodes {
            node.stop()
            node.play()
        }
    }
    
    // MARK: - Sample Selection
    
    private func findSample(for note: UInt8) -> LoadedSample? {
        guard !loadedSamples.isEmpty else { return nil }
        
        // If only one sample, use it
        if loadedSamples.count == 1 { return loadedSamples[0] }
        
        // Find closest root key
        return loadedSamples.min { a, b in
            abs(a.rootKey - Int(note)) < abs(b.rootKey - Int(note))
        }
    }
    
    private func findAvailableNode() -> AVAudioPlayerNode? {
        // Prefer idle node
        if let node = playerNodes.first(where: { activeNodes.values.contains($0) == false }) {
            return node
        }
        // Steal oldest
        return playerNodes.first
    }
    
    // MARK: - Resampling (Pitch Shift via Sample Rate Conversion)
    
    private func resample(pcmData: Data, sourceSampleRate: Double, pitchRatio: Double, volume: Float) -> AVAudioPCMBuffer? {
        let sourceFrames = pcmData.count / 2  // 16-bit mono
        guard sourceFrames > 0 else { return nil }
        
        // Convert Int16 PCM to Float32
        var floatSamples = [Float](repeating: 0, count: sourceFrames)
        pcmData.withUnsafeBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: Int16.self) else { return }
            // Convert Int16 to Float using vDSP
            var scale = Float(1.0 / 32768.0)
            // Manual conversion for safety
            for i in 0..<sourceFrames {
                floatSamples[i] = Float(ptr[i]) / 32768.0
            }
        }
        
        // Apply volume
        if volume < 1.0 {
            vDSP_vsmul(floatSamples, 1, [volume], &floatSamples, 1, vDSP_Length(sourceFrames))
        }
        
        // Calculate output frames: adjust for both pitch and sample rate conversion
        let effectiveRate = sourceSampleRate / pitchRatio
        let outputFrames = Int(Double(sourceFrames) * (outputRate / effectiveRate))
        guard outputFrames > 0, outputFrames < 10_000_000 else { return nil }  // Sanity check
        
        // Resample using linear interpolation
        var outputSamples = [Float](repeating: 0, count: outputFrames)
        let step = Double(sourceFrames - 1) / Double(outputFrames - 1)
        
        for i in 0..<outputFrames {
            let srcPos = Double(i) * step
            let srcIdx = Int(srcPos)
            let frac = Float(srcPos - Double(srcIdx))
            
            if srcIdx + 1 < sourceFrames {
                outputSamples[i] = floatSamples[srcIdx] * (1.0 - frac) + floatSamples[srcIdx + 1] * frac
            } else if srcIdx < sourceFrames {
                outputSamples[i] = floatSamples[srcIdx]
            }
        }
        
        // Create AVAudioPCMBuffer
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(outputFrames)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(outputFrames)
        
        // Copy to buffer
        if let channelData = buffer.floatChannelData?[0] {
            outputSamples.withUnsafeBufferPointer { src in
                channelData.assign(from: src.baseAddress!, count: outputFrames)
            }
        }
        
        return buffer
    }
}
