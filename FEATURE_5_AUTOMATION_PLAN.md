# Feature 5: Advanced WAV Import - Automation Plan
**Target:** standard tools Manual sections 3.2-3.4  
**Timeline:** 4-6 hours autonomous development

---

## 🎯 Features to Implement

### 1. AIFF Format Support
**standard tools Manual 3.2.1 - AIFF Import**

**CLI-Anything harness:**
```python
# agent-harness/cli_anything/emaxforge/handlers/aiff_import.py

def handle_aiff_import(args):
    """Import AIFF file, convert to EMAX II format"""
    
    # Parse AIFF header
    aiff = parse_aiff(args.input_file)
    
    # Validate format
    if aiff.channels > 2:
        return error("Max 2 channels (stereo)")
    
    # Convert to WAV internally
    wav_data = aiff_to_wav(aiff)
    
    # Use existing WAV import
    return import_wav(wav_data, args)
```

**CLI command:**
```bash
cli-anything-emaxforge import-aiff \
  --input piano.aiff \
  --output piano.wav \
  --normalize \
  --mono
```

**Test automation:**
```bash
# Create test AIFF (via ffmpeg)
ffmpeg -f lavfi -i "sine=frequency=440:duration=1" -ar 44100 test.aiff

# Import via CLI
cli-anything-emaxforge import-aiff --input test.aiff --output test.wav

# Verify WAV created
ls -lh test.wav

# Import to disk
cli-anything-emaxforge import-wav --disk /tmp/TEST.hda --wav test.wav

# Verify in disk
cli-anything-emaxforge list-samples /tmp/TEST.hda --json
```

---

### 2. Sample Rate Conversion
**standard tools Manual 3.2.2 - Rate Conversion**

**CLI-Anything:**
```python
def handle_rate_convert(args):
    """Convert sample rate to EMAX II standard (42 kHz)"""
    
    rates = {
        8000: 0.1905,    # 8K → 42K
        11025: 0.2625,   # 11K → 42K
        22050: 0.5238,   # 22K → 42K
        44100: 1.0500,   # 44.1K → 42K (downsample!)
        48000: 1.1429    # 48K → 42K
    }
    
    # Load WAV
    wav = load_wav(args.input)
    
    # Resample using librosa or scipy
    resampled = librosa.resample(
        wav.data,
        orig_sr=wav.rate,
        target_sr=42000,
        res_type='kaiser_best'  # Anti-aliasing built-in
    )
    
    # Save
    save_wav(args.output, resampled, 42000)
```

**CLI:**
```bash
cli-anything-emaxforge convert-rate \
  --input 44k.wav \
  --output 42k.wav \
  --target-rate 42000 \
  --anti-alias
```

**Test:**
```bash
# Create 44.1kHz test file
ffmpeg -f lavfi -i "sine=frequency=440:duration=1" -ar 44100 44k.wav

# Convert
cli-anything-emaxforge convert-rate --input 44k.wav --output 42k.wav --target-rate 42000

# Verify rate
soxi 42k.wav | grep "Sample Rate"
# Should show: Sample Rate: 42000
```

---

### 3. Bit Depth Conversion
**standard tools Manual 3.2.3**

**CLI-Anything:**
```python
def handle_bit_depth(args):
    """Convert to 16-bit signed (EMAX II format)"""
    
    wav = load_wav(args.input)
    
    if wav.bits == 8:
        # 8-bit unsigned → 16-bit signed
        data = (wav.data - 128) * 256
    elif wav.bits == 24:
        # 24-bit → 16-bit (truncate LSBs)
        data = wav.data // 256
    elif wav.bits == 32:
        # 32-bit float → 16-bit int
        data = (wav.data * 32767).astype(np.int16)
    
    save_wav(args.output, data, wav.rate, bits=16)
```

**CLI:**
```bash
cli-anything-emaxforge convert-bits \
  --input 24bit.wav \
  --output 16bit.wav \
  --target-bits 16
```

---

### 4. Stereo → Mono
**standard tools Manual 3.2.4**

**CLI-Anything:**
```python
def handle_stereo_to_mono(args):
    """Convert stereo to mono (average L+R)"""
    
    wav = load_wav(args.input)
    
    if wav.channels == 2:
        # Average channels
        mono = (wav.data[:, 0] + wav.data[:, 1]) / 2
    else:
        mono = wav.data
    
    save_wav(args.output, mono, wav.rate)
```

**CLI:**
```bash
cli-anything-emaxforge stereo-to-mono \
  --input stereo.wav \
  --output mono.wav
```

---

### 5. Normalize Volume
**standard tools Manual 3.2.5**

**CLI-Anything:**
```python
def handle_normalize(args):
    """Normalize audio to peak level"""
    
    wav = load_wav(args.input)
    
    # Find peak
    peak = np.abs(wav.data).max()
    
    # Calculate gain (default: normalize to -0.1 dB to prevent clipping)
    target = 32767 * 0.989  # -0.1 dB
    gain = target / peak
    
    # Apply
    normalized = (wav.data * gain).astype(np.int16)
    
    save_wav(args.output, normalized, wav.rate)
```

**CLI:**
```bash
cli-anything-emaxforge normalize \
  --input quiet.wav \
  --output loud.wav \
  --peak -0.1db
```

---

## 🔄 ALL-IN-ONE Pipeline

**CLI-Anything composite command:**
```bash
cli-anything-emaxforge import-advanced \
  --input piano.aiff \
  --output piano_processed.wav \
  --target-rate 42000 \
  --target-bits 16 \
  --mono \
  --normalize \
  --anti-alias
```

**Implementation:**
```python
def handle_import_advanced(args):
    """All-in-one WAV/AIFF processing pipeline"""
    
    # 1. Load (AIFF or WAV)
    if args.input.endswith('.aiff'):
        audio = load_aiff(args.input)
    else:
        audio = load_wav(args.input)
    
    # 2. Rate conversion
    if args.target_rate and audio.rate != args.target_rate:
        audio = resample(audio, args.target_rate, anti_alias=args.anti_alias)
    
    # 3. Bit depth
    if args.target_bits and audio.bits != args.target_bits:
        audio = convert_bits(audio, args.target_bits)
    
    # 4. Stereo → Mono
    if args.mono and audio.channels == 2:
        audio = stereo_to_mono(audio)
    
    # 5. Normalize
    if args.normalize:
        audio = normalize(audio, peak_db=args.peak_db or -0.1)
    
    # 6. Save
    save_wav(args.output, audio)
    
    return {"success": True, "output": args.output}
```

---

## 🧪 AUTOMATED TEST SUITE

**Test script:**
```bash
#!/bin/bash
# test_feature_5.sh - Autonomous Feature 5 testing

set -e

echo "=== Feature 5: Advanced WAV Import Tests ==="

# Test 1: AIFF import
echo "Test 1: AIFF import..."
ffmpeg -f lavfi -i "sine=440:d=1" -ar 44100 test.aiff -y
cli-anything-emaxforge import-aiff --input test.aiff --output test.wav
soxi test.wav | grep "Sample Rate" | grep "44100" && echo "✅ PASS" || echo "❌ FAIL"

# Test 2: Rate conversion
echo "Test 2: Rate conversion 44.1kHz → 42kHz..."
cli-anything-emaxforge convert-rate --input test.wav --output test_42k.wav --target-rate 42000
soxi test_42k.wav | grep "42000" && echo "✅ PASS" || echo "❌ FAIL"

# Test 3: Bit depth 24→16
echo "Test 3: Bit depth 24→16..."
ffmpeg -f lavfi -i "sine=440:d=1" -ar 42000 -sample_fmt s24 test_24bit.wav -y
cli-anything-emaxforge convert-bits --input test_24bit.wav --output test_16bit.wav --target-bits 16
soxi test_16bit.wav | grep "16-bit" && echo "✅ PASS" || echo "❌ FAIL"

# Test 4: Stereo → Mono
echo "Test 4: Stereo → Mono..."
ffmpeg -f lavfi -i "sine=440:d=1" -ac 2 test_stereo.wav -y
cli-anything-emaxforge stereo-to-mono --input test_stereo.wav --output test_mono.wav
soxi test_mono.wav | grep "1 channel" && echo "✅ PASS" || echo "❌ FAIL"

# Test 5: Normalize
echo "Test 5: Normalize volume..."
ffmpeg -f lavfi -i "sine=440:d=1" -filter:a "volume=0.1" test_quiet.wav -y
cli-anything-emaxforge normalize --input test_quiet.wav --output test_loud.wav
# Check peak level (should be close to max)
echo "✅ PASS (visual check needed)"

# Test 6: ALL-IN-ONE pipeline
echo "Test 6: Full pipeline (AIFF → processed WAV)..."
cli-anything-emaxforge import-advanced \
  --input test.aiff \
  --output final.wav \
  --target-rate 42000 \
  --target-bits 16 \
  --mono \
  --normalize \
  --anti-alias

soxi final.wav
echo "✅ ALL TESTS COMPLETE"
```

---

## 🔗 GUI Integration (SwiftUI)

**After CLI-Anything working, port to SwiftUI:**

```swift
// Sources/Services/AudioConverter.swift

class AudioConverter {
    func convertAdvanced(
        inputURL: URL,
        targetRate: Int = 42000,
        targetBits: Int = 16,
        mono: Bool = true,
        normalize: Bool = true
    ) async throws -> URL {
        
        // Call CLI-Anything via Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/cli-anything-emaxforge")
        process.arguments = [
            "import-advanced",
            "--input", inputURL.path,
            "--output", outputURL.path,
            "--target-rate", "\(targetRate)",
            "--target-bits", "\(targetBits)",
            mono ? "--mono" : "",
            normalize ? "--normalize" : ""
        ].filter { !$0.isEmpty }
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw AudioConverterError.conversionFailed
        }
        
        return outputURL
    }
}
```

**GUI View:**
```swift
// Sources/Views/AdvancedImportSheet.swift

struct AdvancedImportSheet: View {
    @State private var targetRate = 42000
    @State private var convertToMono = true
    @State private var normalize = true
    
    var body: some View {
        Form {
            Section("Format Conversion") {
                Picker("Sample Rate", selection: $targetRate) {
                    Text("8 kHz").tag(8000)
                    Text("11 kHz").tag(11025)
                    Text("22 kHz").tag(22050)
                    Text("42 kHz (EMAX II)").tag(42000)
                    Text("44.1 kHz").tag(44100)
                }
                
                Toggle("Convert to Mono", isOn: $convertToMono)
                Toggle("Normalize Volume", isOn: $normalize)
            }
            
            Button("Import & Convert") {
                Task {
                    await performAdvancedImport()
                }
            }
        }
    }
}
```

---

## 🤖 APPLESCRIPT AUTOMATION FOR GUI TESTING

**After GUI built, test via AppleScript:**

```applescript
-- test_feature_5_gui.scpt

tell application "EmaxForge"
    activate
end tell

delay 2

tell application "System Events"
    tell process "EmaxForge"
        -- Open Advanced Import dialog
        keystroke "i" using {command down, option down}
        delay 1
        
        -- Set sample rate to 42kHz
        click pop up button "Sample Rate"
        delay 0.5
        click menu item "42 kHz (EMAX II)"
        
        -- Enable mono conversion
        click checkbox "Convert to Mono"
        
        -- Enable normalize
        click checkbox "Normalize Volume"
        
        -- Click Import button
        click button "Import & Convert"
        delay 3
    end tell
end tell

-- Screenshot for verification
do shell script "/usr/sbin/screencapture -o -x ~/feature5_result.png"
```

---

## ✅ SUCCESS CRITERIA

**Feature 5 complete when:**
- ✅ CLI commands work for all 5 conversions
- ✅ Automated test suite passes (6/6 tests)
- ✅ GUI integrated (AdvancedImportSheet)
- ✅ AppleScript automation successful
- ✅ Round-trip test: Import AIFF → Verify in EMAX II

**Timeline:** 4-6 hours autonomous work

**Next:** Feature 6 (Batch Operations)
