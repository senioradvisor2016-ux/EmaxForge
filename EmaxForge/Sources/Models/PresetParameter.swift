import Foundation

/// EMAX II Voice Parameter Block (32 bytes per zone)
struct VoiceParameters {
    // Amplitude
    var attenuation: UInt16    // 0x00: 0dB - -96dB
    var tune: UInt16           // 0x02: Pitch offset
    var delay: UInt16          // 0x04: Voice delay
    
    // VCA Envelope
    var vcaAttack: UInt16      // 0x06: Attack time
    var vcaHoldDecay: UInt16   // 0x08: Hold/Decay
    var vcaSustain: UInt16     // 0x0A: Sustain level
    var vcaRelease: UInt16     // 0x0C: Release time
    
    // Filter
    var filterCutoff: UInt16   // 0x0E: Fc (frequency cutoff)
    var filterQ: UInt16        // 0x10: Resonance
    var filterEnvAmount: UInt16 // 0x12: Envelope modulation depth
    var filterAttack: UInt16   // 0x14: Filter envelope attack
    var filterSustain: UInt16  // 0x16: Filter envelope sustain
    var filterRelease: UInt16  // 0x18: Filter envelope release
    
    // Modulation
    var lfo: UInt16            // 0x1A: LFO settings
    var pan: UInt16            // 0x1C: Stereo pan (0x0000=L, 0x4000=C, 0x7FFF=R)
    var chorus: UInt16         // 0x1E: Chorus depth
    
    // MARK: - Init
    
    init() {
        // Factory defaults (open filter, full envelope)
        self.attenuation = 0x0000
        self.tune = 0x4000
        self.delay = 0x0000
        self.vcaAttack = 0x0100
        self.vcaHoldDecay = 0x7F00
        self.vcaSustain = 0xFF00
        self.vcaRelease = 0x0800
        self.filterCutoff = 0x7F00
        self.filterQ = 0x0000
        self.filterEnvAmount = 0x0000
        self.filterAttack = 0x0100
        self.filterSustain = 0xFF00
        self.filterRelease = 0x0800
        self.lfo = 0x0000
        self.pan = 0x4000
        self.chorus = 0x0000
    }
    
    init(from data: Data, offset: Int = 0) {
        if data.count >= offset + 32 {
            self.attenuation = data.readU16LE(at: offset + 0)
            self.tune = data.readU16LE(at: offset + 2)
            self.delay = data.readU16LE(at: offset + 4)
            self.vcaAttack = data.readU16LE(at: offset + 6)
            self.vcaHoldDecay = data.readU16LE(at: offset + 8)
            self.vcaSustain = data.readU16LE(at: offset + 10)
            self.vcaRelease = data.readU16LE(at: offset + 12)
            self.filterCutoff = data.readU16LE(at: offset + 14)
            self.filterQ = data.readU16LE(at: offset + 16)
            self.filterEnvAmount = data.readU16LE(at: offset + 18)
            self.filterAttack = data.readU16LE(at: offset + 20)
            self.filterSustain = data.readU16LE(at: offset + 22)
            self.filterRelease = data.readU16LE(at: offset + 24)
            self.lfo = data.readU16LE(at: offset + 26)
            self.pan = data.readU16LE(at: offset + 28)
            self.chorus = data.readU16LE(at: offset + 30)
        } else {
            // Fallback to defaults
            self.attenuation = 0x0000
            self.tune = 0x4000
            self.delay = 0x0000
            self.vcaAttack = 0x0100
            self.vcaHoldDecay = 0x7F00
            self.vcaSustain = 0xFF00
            self.vcaRelease = 0x0800
            self.filterCutoff = 0x7F00
            self.filterQ = 0x0000
            self.filterEnvAmount = 0x0000
            self.filterAttack = 0x0100
            self.filterSustain = 0xFF00
            self.filterRelease = 0x0800
            self.lfo = 0x0000
            self.pan = 0x4000
            self.chorus = 0x0000
        }
    }
    
    func toData() -> Data {
        var data = Data(count: 32)
        data.writeU16LE(attenuation, at: 0)
        data.writeU16LE(tune, at: 2)
        data.writeU16LE(delay, at: 4)
        data.writeU16LE(vcaAttack, at: 6)
        data.writeU16LE(vcaHoldDecay, at: 8)
        data.writeU16LE(vcaSustain, at: 10)
        data.writeU16LE(vcaRelease, at: 12)
        data.writeU16LE(filterCutoff, at: 14)
        data.writeU16LE(filterQ, at: 16)
        data.writeU16LE(filterEnvAmount, at: 18)
        data.writeU16LE(filterAttack, at: 20)
        data.writeU16LE(filterSustain, at: 22)
        data.writeU16LE(filterRelease, at: 24)
        data.writeU16LE(lfo, at: 26)
        data.writeU16LE(pan, at: 28)
        data.writeU16LE(chorus, at: 30)
        return data
    }
    
    // MARK: - Normalized values (0.0 - 1.0)
    
    var attenuationNorm: Double { Double(attenuation) / 65535.0 }
    var tuneNorm: Double { Double(tune) / 65535.0 }
    var delayNorm: Double { Double(delay) / 65535.0 }
    var vcaAttackNorm: Double { Double(vcaAttack) / 65535.0 }
    var vcaHoldDecayNorm: Double { Double(vcaHoldDecay) / 65535.0 }
    var vcaSustainNorm: Double { Double(vcaSustain) / 65535.0 }
    var vcaReleaseNorm: Double { Double(vcaRelease) / 65535.0 }
    var filterCutoffNorm: Double { Double(filterCutoff) / 65535.0 }
    var filterQNorm: Double { Double(filterQ) / 65535.0 }
    var filterEnvAmountNorm: Double { Double(filterEnvAmount) / 65535.0 }
    var filterAttackNorm: Double { Double(filterAttack) / 65535.0 }
    var filterSustainNorm: Double { Double(filterSustain) / 65535.0 }
    var filterReleaseNorm: Double { Double(filterRelease) / 65535.0 }
    var lfoNorm: Double { Double(lfo) / 65535.0 }
    var panNorm: Double { Double(pan) / 65535.0 }
    var chorusNorm: Double { Double(chorus) / 65535.0 }
    
    // MARK: - Human-readable labels
    
    var panLabel: String {
        if pan < 0x2000 { return "L" }
        if pan > 0x6000 { return "R" }
        return "C"
    }
    
    var filterCutoffHz: Int {
        // Approximate mapping (EMAX II uses 0-127 internally, maps to ~20Hz - 20kHz)
        let normalized = Double(filterCutoff) / 65535.0
        return Int(20 + (20000 - 20) * normalized)
    }
}

// MARK: - Data read/write helpers

private extension Data {
    func readU16LE(at offset: Int) -> UInt16 {
        guard count >= offset + 2 else { return 0 }
        let lo = UInt16(self[offset])
        let hi = UInt16(self[offset + 1])
        return lo | (hi << 8)
    }
    
    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        guard count >= offset + 2 else { return }
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8(value >> 8)
    }
}
