import Foundation
import Accelerate

/// Non-destructive sample editing operations
class SampleEditor {
    
    // MARK: - Edit Operations
    
    /// Crop sample to a specific range
    static func crop(pcmData: Data, startFrame: Int, endFrame: Int) -> Data {
        let totalFrames = pcmData.count / 2
        let safeStart = max(0, min(startFrame, totalFrames))
        let safeEnd = max(safeStart, min(endFrame, totalFrames))
        
        let startByte = safeStart * 2
        let endByte = safeEnd * 2
        
        return pcmData.subdata(in: startByte..<endByte)
    }
    
    /// Trim silence from start and/or end (threshold-based)
    static func trimSilence(pcmData: Data, threshold: Float = 0.01, trimStart: Bool = true, trimEnd: Bool = true) -> Data {
        let frames = pcmData.count / 2
        guard frames > 0 else { return pcmData }
        
        var samples = [Int16](repeating: 0, count: frames)
        pcmData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                samples[i] = Int16(littleEndian: int16Ptr[i])
            }
        }
        
        let thresholdInt = Int16(threshold * Float(Int16.max))
        
        // Find first non-silent frame
        var startFrame = 0
        if trimStart {
            for i in 0..<frames {
                if abs(samples[i]) > thresholdInt {
                    startFrame = i
                    break
                }
            }
        }
        
        // Find last non-silent frame
        var endFrame = frames
        if trimEnd {
            for i in stride(from: frames - 1, through: 0, by: -1) {
                if abs(samples[i]) > thresholdInt {
                    endFrame = i + 1
                    break
                }
            }
        }
        
        return crop(pcmData: pcmData, startFrame: startFrame, endFrame: endFrame)
    }
    
    /// Normalize to peak amplitude (0.0 - 1.0, where 1.0 = 100%)
    static func normalize(pcmData: Data, targetPeak: Float = 1.0) -> Data {
        let frames = pcmData.count / 2
        guard frames > 0 else { return pcmData }
        
        var samples = [Int16](repeating: 0, count: frames)
        pcmData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                samples[i] = Int16(littleEndian: int16Ptr[i])
            }
        }
        
        // Find peak
        let peak = samples.map { abs($0) }.max() ?? 1
        guard peak > 0 else { return pcmData }
        
        let targetPeakInt = Int16(targetPeak * Float(Int16.max))
        let gain = Float(targetPeakInt) / Float(peak)
        
        // Apply gain
        var normalized = Data(capacity: pcmData.count)
        for sample in samples {
            let scaled = Int16(max(Float(Int16.min), min(Float(Int16.max), Float(sample) * gain)))
            var le = scaled.littleEndian
            normalized.append(Data(bytes: &le, count: 2))
        }
        
        return normalized
    }
    
    /// Apply fade in (linear envelope)
    static func fadeIn(pcmData: Data, durationMs: Double, sampleRate: Double = 28000) -> Data {
        let frames = pcmData.count / 2
        let fadeFrames = min(Int(durationMs / 1000.0 * sampleRate), frames)
        
        guard fadeFrames > 0 else { return pcmData }
        
        var samples = [Int16](repeating: 0, count: frames)
        pcmData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                samples[i] = Int16(littleEndian: int16Ptr[i])
            }
        }
        
        // Apply fade
        for i in 0..<fadeFrames {
            let gain = Float(i) / Float(fadeFrames)
            samples[i] = Int16(Float(samples[i]) * gain)
        }
        
        // Write back
        var faded = Data(capacity: pcmData.count)
        for sample in samples {
            var le = sample.littleEndian
            faded.append(Data(bytes: &le, count: 2))
        }
        
        return faded
    }
    
    /// Apply fade out (linear envelope)
    static func fadeOut(pcmData: Data, durationMs: Double, sampleRate: Double = 28000) -> Data {
        let frames = pcmData.count / 2
        let fadeFrames = min(Int(durationMs / 1000.0 * sampleRate), frames)
        
        guard fadeFrames > 0 else { return pcmData }
        
        var samples = [Int16](repeating: 0, count: frames)
        pcmData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                samples[i] = Int16(littleEndian: int16Ptr[i])
            }
        }
        
        // Apply fade
        let startFrame = frames - fadeFrames
        for i in 0..<fadeFrames {
            let gain = 1.0 - (Float(i) / Float(fadeFrames))
            samples[startFrame + i] = Int16(Float(samples[startFrame + i]) * gain)
        }
        
        // Write back
        var faded = Data(capacity: pcmData.count)
        for sample in samples {
            var le = sample.littleEndian
            faded.append(Data(bytes: &le, count: 2))
        }
        
        return faded
    }
    
    /// Apply both fade in and fade out
    static func fade(pcmData: Data, fadeInMs: Double, fadeOutMs: Double, sampleRate: Double = 28000) -> Data {
        var result = pcmData
        if fadeInMs > 0 {
            result = fadeIn(pcmData: result, durationMs: fadeInMs, sampleRate: sampleRate)
        }
        if fadeOutMs > 0 {
            result = fadeOut(pcmData: result, durationMs: fadeOutMs, sampleRate: sampleRate)
        }
        return result
    }
    
    /// Reverse the sample
    static func reverse(pcmData: Data) -> Data {
        let frames = pcmData.count / 2
        guard frames > 0 else { return pcmData }
        
        var samples = [Int16](repeating: 0, count: frames)
        pcmData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                samples[i] = Int16(littleEndian: int16Ptr[i])
            }
        }
        
        samples.reverse()
        
        var reversed = Data(capacity: pcmData.count)
        for sample in samples {
            var le = sample.littleEndian
            reversed.append(Data(bytes: &le, count: 2))
        }
        
        return reversed
    }
    
    /// Change gain (volume) by dB
    static func changeGain(pcmData: Data, gainDb: Float) -> Data {
        let frames = pcmData.count / 2
        guard frames > 0 else { return pcmData }
        
        // Convert dB to linear gain
        let linearGain = pow(10.0, gainDb / 20.0)
        
        var samples = [Int16](repeating: 0, count: frames)
        pcmData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                samples[i] = Int16(littleEndian: int16Ptr[i])
            }
        }
        
        // Apply gain
        var gained = Data(capacity: pcmData.count)
        for sample in samples {
            let scaled = Int16(max(Float(Int16.min), min(Float(Int16.max), Float(sample) * linearGain)))
            var le = scaled.littleEndian
            gained.append(Data(bytes: &le, count: 2))
        }
        
        return gained
    }
    
    // MARK: - Analysis
    
    /// Get peak amplitude (0.0 - 1.0)
    static func getPeak(pcmData: Data) -> Float {
        let frames = pcmData.count / 2
        guard frames > 0 else { return 0 }
        
        var peak: Int16 = 0
        pcmData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                let sample = Int16(littleEndian: int16Ptr[i])
                if abs(sample) > abs(peak) {
                    peak = sample
                }
            }
        }
        
        return Float(abs(peak)) / Float(Int16.max)
    }
    
    /// Get RMS (root mean square) level
    static func getRMS(pcmData: Data) -> Float {
        let frames = pcmData.count / 2
        guard frames > 0 else { return 0 }
        
        var sum: Double = 0
        pcmData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                let sample = Double(Int16(littleEndian: int16Ptr[i]))
                sum += sample * sample
            }
        }
        
        let rms = sqrt(sum / Double(frames))
        return Float(rms / Double(Int16.max))
    }
    
    /// Detect zero-crossings (useful for finding good loop points)
    static func findZeroCrossings(pcmData: Data, near frame: Int, searchRange: Int = 100) -> Int? {
        let frames = pcmData.count / 2
        guard frames > 0 else { return nil }
        
        var samples = [Int16](repeating: 0, count: frames)
        pcmData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for i in 0..<frames {
                samples[i] = Int16(littleEndian: int16Ptr[i])
            }
        }
        
        let start = max(0, frame - searchRange)
        let end = min(frames - 1, frame + searchRange)
        
        // Find closest zero crossing
        var closestFrame: Int?
        var closestDist = Int.max
        
        for i in start..<end {
            if i > 0 {
                let curr = samples[i]
                let prev = samples[i - 1]
                
                // Zero crossing detected
                if (curr >= 0 && prev < 0) || (curr < 0 && prev >= 0) {
                    let dist = abs(i - frame)
                    if dist < closestDist {
                        closestDist = dist
                        closestFrame = i
                    }
                }
            }
        }
        
        return closestFrame
    }
}
