import XCTest
import Foundation
@testable import EmaxForge

/// Tests for SampleEditor — pure in-memory DSP operations.
/// All functions take Data (16-bit LE PCM) and return Data; no disk I/O.
final class SampleEditorTests: XCTestCase {

    // MARK: - Helpers

    /// Build little-endian 16-bit PCM Data from an Int16 array.
    private func pcm(_ values: [Int16]) -> Data {
        var data = Data(capacity: values.count * 2)
        for v in values {
            var le = v.littleEndian
            data.append(Data(bytes: &le, count: 2))
        }
        return data
    }

    /// Read little-endian Int16 samples back out of Data.
    private func samples(_ data: Data) -> [Int16] {
        var result = [Int16]()
        result.reserveCapacity(data.count / 2)
        data.withUnsafeBytes { ptr in
            let p = ptr.bindMemory(to: Int16.self)
            for i in 0..<(data.count / 2) {
                result.append(Int16(littleEndian: p[i]))
            }
        }
        return result
    }

    // MARK: - crop

    func testCropBasicRange() {
        let data = pcm([10, 20, 30, 40, 50])
        let result = SampleEditor.crop(pcmData: data, startFrame: 1, endFrame: 3)
        XCTAssertEqual(samples(result), [20, 30])
    }

    func testCropEntireRange() {
        let data = pcm([10, 20, 30])
        let result = SampleEditor.crop(pcmData: data, startFrame: 0, endFrame: 3)
        XCTAssertEqual(samples(result), [10, 20, 30])
    }

    func testCropEmptyRange() {
        let data = pcm([10, 20, 30])
        let result = SampleEditor.crop(pcmData: data, startFrame: 2, endFrame: 2)
        XCTAssertEqual(result.count, 0)
    }

    func testCropClampsBelowZero() {
        // startFrame < 0 → clamped to 0
        let data = pcm([10, 20, 30])
        let result = SampleEditor.crop(pcmData: data, startFrame: -5, endFrame: 2)
        XCTAssertEqual(samples(result), [10, 20])
    }

    func testCropClampsAboveEnd() {
        // endFrame beyond total → clamped to totalFrames
        let data = pcm([10, 20, 30])
        let result = SampleEditor.crop(pcmData: data, startFrame: 1, endFrame: 1000)
        XCTAssertEqual(samples(result), [20, 30])
    }

    func testCropOutputSizeIs2xFrameCount() {
        let data = pcm([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        let result = SampleEditor.crop(pcmData: data, startFrame: 0, endFrame: 4)
        XCTAssertEqual(result.count, 4 * 2)
    }

    func testCropSingleFrame() {
        let data = pcm([100, 200, 300])
        let result = SampleEditor.crop(pcmData: data, startFrame: 1, endFrame: 2)
        XCTAssertEqual(samples(result), [200])
    }

    func testCropEmptyInput() {
        let result = SampleEditor.crop(pcmData: Data(), startFrame: 0, endFrame: 5)
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - trimSilence

    func testTrimSilenceRemovesLeadingZeros() {
        // [0, 0, 1000, 2000] → trimmed from start → [1000, 2000]
        let data = pcm([0, 0, 1000, 2000])
        let result = SampleEditor.trimSilence(pcmData: data, threshold: 0.001)
        let s = samples(result)
        XCTAssertTrue(s.contains(1000), "Should contain 1000 after trim")
        XCTAssertFalse(samples(result).first == 0, "Leading zero should be trimmed")
    }

    func testTrimSilenceRemovesTrailingZeros() {
        // [1000, 2000, 0, 0] → trimmed from end → [1000, 2000]
        let data = pcm([1000, 2000, 0, 0])
        let result = SampleEditor.trimSilence(pcmData: data, threshold: 0.001)
        let s = samples(result)
        XCTAssertTrue(s.contains(2000))
        XCTAssertFalse(s.last == 0, "Trailing zero should be trimmed")
    }

    func testTrimSilenceAllAboveThresholdSizeSame() {
        let data = pcm([1000, 2000, 3000, 4000])
        let result = SampleEditor.trimSilence(pcmData: data, threshold: 0.001)
        XCTAssertEqual(result.count, data.count,
                       "No silence to trim: output size should match input")
    }

    func testTrimSilenceAllBelowThresholdReturnsFullData() {
        // All zeros, threshold=1.0 → no frame exceeds threshold → startFrame=0, endFrame=n
        let data = pcm([0, 0, 0])
        let result = SampleEditor.trimSilence(pcmData: data, threshold: 1.0)
        XCTAssertEqual(result.count, data.count,
                       "All-silent data: trim logic returns full data")
    }

    func testTrimSilenceEmptyInput() {
        let result = SampleEditor.trimSilence(pcmData: Data())
        XCTAssertEqual(result.count, 0)
    }

    func testTrimSilenceOnlyStart() {
        // trimStart=true, trimEnd=false → trailing zeros preserved
        let data = pcm([0, 0, 500, 600, 0])
        let result = SampleEditor.trimSilence(pcmData: data, threshold: 0.001,
                                              trimStart: true, trimEnd: false)
        let s = samples(result)
        XCTAssertEqual(s.first, 500, "Trim start should remove leading zeros")
        XCTAssertEqual(s.last, 0, "Trailing zero should be preserved when trimEnd=false")
    }

    func testTrimSilenceOnlyEnd() {
        // trimStart=false, trimEnd=true → leading zeros preserved
        let data = pcm([0, 0, 500, 600, 0])
        let result = SampleEditor.trimSilence(pcmData: data, threshold: 0.001,
                                              trimStart: false, trimEnd: true)
        let s = samples(result)
        XCTAssertEqual(s.first, 0, "Leading zero should be preserved when trimStart=false")
        XCTAssertEqual(s.last, 600, "Trailing zero should be trimmed")
    }

    // MARK: - normalize

    func testNormalizeEmptyReturnsEmpty() {
        let result = SampleEditor.normalize(pcmData: Data())
        XCTAssertEqual(result.count, 0)
    }

    func testNormalizeAllZeroReturnsUnchanged() {
        // guard peak > 0 → returns pcmData unchanged
        let data = pcm([0, 0, 0])
        let result = SampleEditor.normalize(pcmData: data)
        XCTAssertEqual(result, data)
    }

    func testNormalizeSizePreserved() {
        let data = pcm([100, -200, 300, -400, 500])
        let result = SampleEditor.normalize(pcmData: data)
        XCTAssertEqual(result.count, data.count)
    }

    func testNormalizePeakIsMaxAfterNormalization() {
        let data = pcm([1000, -500, 800])
        let result = SampleEditor.normalize(pcmData: data)
        let peak = SampleEditor.getPeak(pcmData: result)
        XCTAssertEqual(peak, 1.0, accuracy: 0.001,
                       "After normalize(targetPeak=1.0), peak should be ~1.0")
    }

    func testNormalizeAlreadyAtPeakUnchanged() {
        let data = pcm([32767])
        let result = SampleEditor.normalize(pcmData: data)
        let s = samples(result)
        XCTAssertEqual(s[0], 32767)
    }

    // MARK: - getPeak

    func testGetPeakEmptyReturnsZero() {
        XCTAssertEqual(SampleEditor.getPeak(pcmData: Data()), 0.0, accuracy: 0.0001)
    }

    func testGetPeakSingleMax() {
        let data = pcm([32767])
        XCTAssertEqual(SampleEditor.getPeak(pcmData: data), 1.0, accuracy: 0.0001)
    }

    func testGetPeakPicksLargestAbsolute() {
        // peak should pick |−500| over |300|
        let data = pcm([300, -500, 200])
        let peak = SampleEditor.getPeak(pcmData: data)
        let expected = Float(500) / Float(Int16.max)
        XCTAssertEqual(peak, expected, accuracy: 0.001)
    }

    func testGetPeakAllSilentIsZero() {
        let data = pcm([0, 0, 0])
        XCTAssertEqual(SampleEditor.getPeak(pcmData: data), 0.0, accuracy: 0.0001)
    }

    // MARK: - getRMS

    func testGetRMSEmptyReturnsZero() {
        XCTAssertEqual(SampleEditor.getRMS(pcmData: Data()), 0.0, accuracy: 0.0001)
    }

    func testGetRMSSingleMaxValue() {
        let data = pcm([32767])
        XCTAssertEqual(SampleEditor.getRMS(pcmData: data), 1.0, accuracy: 0.001)
    }

    func testGetRMSAllZeroIsZero() {
        let data = pcm([0, 0, 0])
        XCTAssertEqual(SampleEditor.getRMS(pcmData: data), 0.0, accuracy: 0.0001)
    }

    func testGetRMSUniformSignalEqualsAmplitudeRatio() {
        // All samples = 1000: RMS = 1000 / 32767 ≈ 0.03052
        let data = pcm([1000, 1000, 1000, 1000])
        let expected = Float(1000) / Float(Int16.max)
        XCTAssertEqual(SampleEditor.getRMS(pcmData: data), expected, accuracy: 0.001)
    }

    // MARK: - reverse

    func testReverseBasicOrder() {
        let data = pcm([10, 20, 30])
        let result = SampleEditor.reverse(pcmData: data)
        XCTAssertEqual(samples(result), [30, 20, 10])
    }

    func testReverseTwiceIsIdentity() {
        let data = pcm([100, 200, 300, 400, 500])
        let once = SampleEditor.reverse(pcmData: data)
        let twice = SampleEditor.reverse(pcmData: once)
        XCTAssertEqual(samples(twice), [100, 200, 300, 400, 500])
    }

    func testReverseSizePreserved() {
        let data = pcm([1, 2, 3, 4, 5])
        let result = SampleEditor.reverse(pcmData: data)
        XCTAssertEqual(result.count, data.count)
    }

    func testReverseEmptyInput() {
        let result = SampleEditor.reverse(pcmData: Data())
        XCTAssertEqual(result.count, 0)
    }

    func testReverseSingleFrame() {
        let data = pcm([999])
        let result = SampleEditor.reverse(pcmData: data)
        XCTAssertEqual(samples(result), [999])
    }

    // MARK: - changeGain

    func testChangeGain0DbIsNoop() {
        let data = pcm([1000, -2000, 3000])
        let result = SampleEditor.changeGain(pcmData: data, gainDb: 0.0)
        // 0 dB → gain=1.0 → samples unchanged
        XCTAssertEqual(samples(result), [1000, -2000, 3000])
    }

    func testChangeGainSizePreserved() {
        let data = pcm([100, 200, 300])
        let result = SampleEditor.changeGain(pcmData: data, gainDb: 6.0)
        XCTAssertEqual(result.count, data.count)
    }

    func testChangeGain6DbApproximatelyDoublesAmplitude() {
        // +6 dB → linear gain ≈ 2.0 (pow(10, 6/20) ≈ 1.995)
        let data = pcm([1000])
        let result = SampleEditor.changeGain(pcmData: data, gainDb: 6.0)
        let s = samples(result)
        XCTAssertGreaterThan(s[0], 1900, "+6dB should approximately double the sample")
        XCTAssertLessThan(s[0], 2100)
    }

    func testChangeGainNegativeHalvesApproximately() {
        // -6 dB → linear gain ≈ 0.5
        let data = pcm([10000])
        let result = SampleEditor.changeGain(pcmData: data, gainDb: -6.0)
        let s = samples(result)
        XCTAssertGreaterThan(s[0], 4500, "-6dB should approximately halve the sample")
        XCTAssertLessThan(s[0], 5500)
    }

    func testChangeGainClampsAtMax() {
        // Very large gain on non-zero sample → clamped to Int16.max
        let data = pcm([1000])
        let result = SampleEditor.changeGain(pcmData: data, gainDb: 120.0)
        let s = samples(result)
        XCTAssertEqual(s[0], Int16.max, "Overdriven gain should clamp to Int16.max")
    }

    func testChangeGainEmptyInput() {
        let result = SampleEditor.changeGain(pcmData: Data(), gainDb: 6.0)
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - fadeIn

    func testFadeInSizePreserved() {
        let data = pcm([1000, 1000, 1000, 1000, 1000])
        let result = SampleEditor.fadeIn(pcmData: data, durationMs: 1.0)
        XCTAssertEqual(result.count, data.count)
    }

    func testFadeInFirstSampleIsZero() {
        // Gain at i=0 is 0/fadeFrames = 0 → first sample * 0 = 0
        let data = pcm([30000, 30000, 30000, 30000, 30000, 30000, 30000, 30000])
        // 1ms at 28000 Hz = 28 frames; our data has 8 frames, so fadeFrames = 8
        let result = SampleEditor.fadeIn(pcmData: data, durationMs: 1.0, sampleRate: 8000)
        // At 8000 Hz, 1ms = 8 frames. With 8 frames input, fadeFrames = 8.
        // i=0: gain = 0/8 = 0 → sample = 0
        let s = samples(result)
        XCTAssertEqual(s[0], 0, "First sample of fade-in should be 0 (gain=0)")
    }

    func testFadeInBeyondDurationSamplesUnchanged() {
        // 4 frames at 1000 Hz, 1ms = 1 frame fade. Frames after index 0 are unchanged.
        let data = pcm([1000, 2000, 3000, 4000])
        let result = SampleEditor.fadeIn(pcmData: data, durationMs: 1.0, sampleRate: 1000)
        // fadeFrames = min(1, 4) = 1. Only frame 0 is faded; frames 1-3 are unchanged.
        let s = samples(result)
        XCTAssertEqual(s[1], 2000, "Frames after fade region should be unchanged")
        XCTAssertEqual(s[2], 3000)
        XCTAssertEqual(s[3], 4000)
    }

    // MARK: - fadeOut

    func testFadeOutSizePreserved() {
        let data = pcm([1000, 1000, 1000, 1000])
        let result = SampleEditor.fadeOut(pcmData: data, durationMs: 1.0)
        XCTAssertEqual(result.count, data.count)
    }

    func testFadeOutPreservesFramesBeforeFadeRegion() {
        // 4 frames, 1ms at 1000 Hz → fadeFrames = 1. startFrame = 4-1 = 3.
        // Only frame 3 is faded. Frames 0-2 are unchanged.
        let data = pcm([100, 200, 300, 400])
        let result = SampleEditor.fadeOut(pcmData: data, durationMs: 1.0, sampleRate: 1000)
        let s = samples(result)
        XCTAssertEqual(s[0], 100)
        XCTAssertEqual(s[1], 200)
        XCTAssertEqual(s[2], 300)
    }

    func testFadeOutEmptyInput() {
        let result = SampleEditor.fadeOut(pcmData: Data(), durationMs: 10.0)
        XCTAssertEqual(result.count, 0)
    }

    // MARK: - fade (combined)

    func testFadeCombinedSizePreserved() {
        let data = pcm([1000, 2000, 3000, 4000, 5000])
        let result = SampleEditor.fade(pcmData: data, fadeInMs: 1.0, fadeOutMs: 1.0)
        XCTAssertEqual(result.count, data.count)
    }

    func testFadeZeroMsIsNoop() {
        let data = pcm([1000, 2000, 3000])
        let result = SampleEditor.fade(pcmData: data, fadeInMs: 0.0, fadeOutMs: 0.0)
        XCTAssertEqual(samples(result), [1000, 2000, 3000])
    }

    // MARK: - findZeroCrossings

    func testFindZeroCrossingsEmptyReturnsNil() {
        XCTAssertNil(SampleEditor.findZeroCrossings(pcmData: Data(), near: 0))
    }

    func testFindZeroCrossingsDetectsBasicCrossing() {
        // Loop bound is min(frames-1, near+searchRange), so use ≥4 frames.
        // [100, 100, -100, -100] → crossing at frame 2 (negative after positive)
        // near=2, searchRange=2 → start=0, end=min(3,4)=3 → loop i=0,1,2
        // At i=2: curr=-100, prev=100 → crossing! dist=|2-2|=0 → returns 2
        let data = pcm([100, 100, -100, -100])
        let result = SampleEditor.findZeroCrossings(pcmData: data, near: 2, searchRange: 2)
        XCTAssertNotNil(result)
        XCTAssertEqual(result, 2)
    }

    func testFindZeroCrossingsNoCrossingReturnsNil() {
        // All same sign → no zero crossing
        let data = pcm([100, 200, 300, 400])
        let result = SampleEditor.findZeroCrossings(pcmData: data, near: 2, searchRange: 2)
        XCTAssertNil(result)
    }

    func testFindZeroCrossingsFindsNearestCrossing() {
        // [100, 100, -100, -100, 100] → crossings at frame 2 and 4
        // near frame 3 with searchRange=5: both are candidates, frame 2 has dist=1, frame 4 has dist=1
        // Finds the one encountered first in the loop (frame 2)
        let data = pcm([100, 100, -100, -100, 100])
        let result = SampleEditor.findZeroCrossings(pcmData: data, near: 3, searchRange: 5)
        XCTAssertNotNil(result)
    }
}
