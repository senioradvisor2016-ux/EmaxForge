import Foundation
import AVFoundation
import Combine

/// Plays raw 16-bit PCM sample data extracted from EMAX II banks
class SamplePlayer: ObservableObject {
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0  // 0.0 – 1.0
    @Published var currentSampleRate: Double = 28000
    
    private var displayLink: Any?
    private var totalFrames: AVAudioFrameCount = 0
    private var scheduledBuffer: AVAudioPCMBuffer?
    private var progressTimer: Timer?
    private var startHostTime: UInt64 = 0
    
    /// EMAX II native sample rates
    /// ADC always records at ~39.0625 kHz, DSP downconverts to lower rates.
    /// NS32CG16 CPU (little-endian). Playback engine runs at 44.1kHz.
    static let sampleRates: [Double] = [20000, 22050, 27778, 31250, 39063, 44100]
    
    init() {
        engine.attach(playerNode)
    }
    
    deinit {
        stop()
        engine.stop()
    }
    
    // MARK: - Playback
    
    /// Play raw 16-bit signed PCM data (little-endian mono)
    func play(pcmData: Data, sampleRate: Double = 28000) {
        stop()
        
        guard pcmData.count >= 4 else { return }
        
        currentSampleRate = sampleRate
        let frameCount = pcmData.count / 2  // 16-bit = 2 bytes per frame
        totalFrames = AVAudioFrameCount(frameCount)
        
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return }
        buffer.frameLength = totalFrames
        
        // Convert 16-bit signed LE PCM → Float32
        guard let floatData = buffer.floatChannelData?[0] else { return }
        
        pcmData.withUnsafeBytes { rawBuf in
            let int16Ptr = rawBuf.bindMemory(to: Int16.self)
            for i in 0..<frameCount {
                let sample = Int16(littleEndian: int16Ptr[i])
                floatData[i] = Float(sample) / Float(Int16.max)
            }
        }
        
        scheduledBuffer = buffer
        
        // Connect and start
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
        } catch {
            print("SamplePlayer: engine start failed: \(error)")
            return
        }
        
        playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async {
                self?.playbackFinished()
            }
        }
        
        playerNode.play()
        isPlaying = true
        playbackProgress = 0
        startHostTime = mach_absolute_time()
        
        startProgressTimer()
    }
    
    /// Play raw 16-bit signed PCM data (big-endian mono — original EMAX II hardware format)
    func playBigEndian(pcmData: Data, sampleRate: Double = 28000) {
        // Byte-swap to little-endian first
        var leData = Data(count: pcmData.count)
        let frameCount = pcmData.count / 2
        
        pcmData.withUnsafeBytes { src in
            leData.withUnsafeMutableBytes { dst in
                let srcBytes = src.bindMemory(to: UInt8.self)
                let dstBytes = dst.bindMemory(to: UInt8.self)
                for i in 0..<frameCount {
                    dstBytes[i * 2] = srcBytes[i * 2 + 1]
                    dstBytes[i * 2 + 1] = srcBytes[i * 2]
                }
            }
        }
        
        play(pcmData: leData, sampleRate: sampleRate)
    }
    
    func stop() {
        progressTimer?.invalidate()
        progressTimer = nil
        
        if isPlaying {
            playerNode.stop()
            engine.stop()
            engine.disconnectNodeOutput(playerNode)
        }
        
        isPlaying = false
        playbackProgress = 0
        scheduledBuffer = nil
    }
    
    func togglePlayback(pcmData: Data, sampleRate: Double = 28000) {
        if isPlaying {
            stop()
        } else {
            play(pcmData: pcmData, sampleRate: sampleRate)
        }
    }
    
    // MARK: - Progress
    
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func updateProgress() {
        guard isPlaying, totalFrames > 0 else { return }
        
        if let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            let progress = Double(playerTime.sampleTime) / Double(totalFrames)
            playbackProgress = min(max(progress, 0), 1)
        }
    }
    
    private func playbackFinished() {
        isPlaying = false
        playbackProgress = 1.0
        progressTimer?.invalidate()
        progressTimer = nil
        
        engine.stop()
        engine.disconnectNodeOutput(playerNode)
    }
    
    // MARK: - Waveform Data
    
    /// Generate normalized float samples for waveform display (downsampled for UI)
    static func waveformSamples(from pcmData: Data, targetPoints: Int = 200) -> [Float] {
        let frameCount = pcmData.count / 2
        guard frameCount > 0 else { return [] }
        
        let samplesPerPoint = max(1, frameCount / targetPoints)
        var waveform = [Float]()
        waveform.reserveCapacity(targetPoints)
        
        pcmData.withUnsafeBytes { rawBuf in
            let int16Ptr = rawBuf.bindMemory(to: Int16.self)
            
            for point in 0..<min(targetPoints, frameCount) {
                let start = point * samplesPerPoint
                let end = min(start + samplesPerPoint, frameCount)
                
                var maxAbs: Float = 0
                for i in start..<end {
                    let sample = Int16(littleEndian: int16Ptr[i])
                    let normalized = abs(Float(sample) / Float(Int16.max))
                    if normalized > maxAbs { maxAbs = normalized }
                }
                waveform.append(maxAbs)
            }
        }
        
        return waveform
    }
    
    /// Duration in seconds
    var duration: Double {
        guard totalFrames > 0 else { return 0 }
        return Double(totalFrames) / currentSampleRate
    }
    
    /// Format duration as "0:00.0"
    static func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = seconds - Double(mins * 60)
        return String(format: "%d:%04.1f", mins, secs)
    }
}
