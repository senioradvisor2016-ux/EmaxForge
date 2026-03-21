# Feature 6: Batch Operations - Automation Plan
**Target:** standard tools Manual sections 5.3-5.4  
**Timeline:** 3-4 hours autonomous development

---

## 🎯 Features to Implement

### 1. Batch WAV → Sample Conversion
**standard tools Manual 5.3.1 - Batch Convert**

**CLI-Anything:**
```python
# agent-harness/cli_anything/emaxforge/handlers/batch.py

def handle_batch_convert(args):
    """Convert multiple WAV/AIFF files in one operation"""
    
    files = glob.glob(args.pattern)
    results = []
    
    for file in files:
        try:
            # Use Feature 5's advanced import
            output = convert_advanced(
                file,
                target_rate=args.rate,
                mono=args.mono,
                normalize=args.normalize
            )
            results.append({"file": file, "status": "success", "output": output})
        except Exception as e:
            results.append({"file": file, "status": "error", "error": str(e)})
    
    # Progress reporting
    success = len([r for r in results if r["status"] == "success"])
    print(f"✅ Converted {success}/{len(files)} files")
    
    return {"results": results, "total": len(files), "success": success}
```

**CLI:**
```bash
# Convert all WAV files in folder
cli-anything-emaxforge batch-convert \
  --pattern "samples/*.wav" \
  --output-dir "converted/" \
  --target-rate 42000 \
  --mono \
  --normalize \
  --progress

# With wildcards
cli-anything-emaxforge batch-convert \
  --pattern "**/*.{wav,aiff}" \
  --recursive \
  --output-dir "processed/"
```

**Test:**
```bash
# Create test files
mkdir -p test_batch
for i in {1..10}; do
  ffmpeg -f lavfi -i "sine=frequency=$((440 + i*10)):duration=0.5" \
    -ar 44100 test_batch/sample_$i.wav -y
done

# Batch convert
cli-anything-emaxforge batch-convert \
  --pattern "test_batch/*.wav" \
  --output-dir "test_batch/converted" \
  --target-rate 42000 \
  --progress

# Verify
ls test_batch/converted/*.wav | wc -l
# Should be 10
```

---

### 2. Batch Bank Import
**standard tools Manual 5.3.2**

**CLI-Anything:**
```python
def handle_batch_import_banks(args):
    """Import multiple .EB2 banks to disk"""
    
    banks = glob.glob(args.pattern)
    disk = HDImage(args.disk)
    
    results = []
    
    for bank in banks:
        try:
            disk.import_bank(bank)
            results.append({"bank": bank, "status": "imported"})
            
            # Progress
            progress = len(results) / len(banks) * 100
            print(f"Progress: {progress:.1f}% ({len(results)}/{len(banks)})")
            
        except Exception as e:
            results.append({"bank": bank, "status": "error", "error": str(e)})
    
    return {
        "total": len(banks),
        "imported": len([r for r in results if r["status"] == "imported"]),
        "errors": len([r for r in results if r["status"] == "error"])
    }
```

**CLI:**
```bash
# Import all banks from folder
cli-anything-emaxforge batch-import-banks \
  --disk /Volumes/ZULUSCI/HD20.hda \
  --pattern "~/banks/*.EB2" \
  --progress

# With confirmation
cli-anything-emaxforge batch-import-banks \
  --disk HD20.hda \
  --pattern "*.EB2" \
  --confirm \
  --dry-run  # Preview only
```

**Test:**
```bash
# Create test disk
cli-anything-emaxforge create-disk --size 239 --output /tmp/BATCH_TEST.hda

# Batch import (already have 52 banks from earlier!)
cli-anything-emaxforge batch-import-banks \
  --disk /tmp/BATCH_TEST.hda \
  --pattern "~/clawd/standard/*.EB2" \
  --progress

# Verify
cli-anything-emaxforge list-banks /tmp/BATCH_TEST.hda --json | jq '.count'
# Should be 52
```

---

### 3. Batch Export All Banks
**standard tools Manual 5.3.3**

**CLI-Anything:**
```python
def handle_batch_export_banks(args):
    """Export all banks from disk to folder"""
    
    disk = HDImage(args.disk)
    banks = disk.list_banks()
    
    os.makedirs(args.output_dir, exist_ok=True)
    results = []
    
    for bank in banks:
        try:
            output_path = os.path.join(args.output_dir, f"{bank.name}.EB2")
            disk.export_bank(bank.name, output_path)
            results.append({"bank": bank.name, "status": "exported", "path": output_path})
            
            # Progress
            progress = len(results) / len(banks) * 100
            print(f"Progress: {progress:.1f}% ({len(results)}/{len(banks)})")
            
        except Exception as e:
            results.append({"bank": bank.name, "status": "error", "error": str(e)})
    
    return {
        "total": len(banks),
        "exported": len([r for r in results if r["status"] == "exported"]),
        "errors": len([r for r in results if r["status"] == "error"])
    }
```

**CLI:**
```bash
# Export all banks
cli-anything-emaxforge batch-export-banks \
  --disk /Volumes/ZULUSCI/HD10.hda \
  --output-dir ~/exported_banks/ \
  --progress

# With filters
cli-anything-emaxforge batch-export-banks \
  --disk HD10.hda \
  --output-dir ~/banks/ \
  --filter "BRASS*" \
  --overwrite
```

**Test:**
```bash
# Export from test disk
mkdir -p /tmp/exported
cli-anything-emaxforge batch-export-banks \
  --disk /tmp/BATCH_TEST.hda \
  --output-dir /tmp/exported \
  --progress

# Verify count
ls /tmp/exported/*.EB2 | wc -l
# Should be 52

# Verify round-trip (re-import)
cli-anything-emaxforge create-disk --size 239 --output /tmp/ROUNDTRIP.hda
cli-anything-emaxforge batch-import-banks \
  --disk /tmp/ROUNDTRIP.hda \
  --pattern "/tmp/exported/*.EB2"

cli-anything-emaxforge list-banks /tmp/ROUNDTRIP.hda --json | jq '.count'
# Should still be 52
```

---

### 4. Progress Reporting
**standard tools Manual 5.4.1**

**CLI-Anything:**
```python
class ProgressReporter:
    """Real-time progress for batch operations"""
    
    def __init__(self, total):
        self.total = total
        self.current = 0
        self.start_time = time.time()
    
    def update(self, increment=1):
        self.current += increment
        percent = (self.current / self.total) * 100
        elapsed = time.time() - self.start_time
        rate = self.current / elapsed if elapsed > 0 else 0
        eta = (self.total - self.current) / rate if rate > 0 else 0
        
        # Print progress bar
        bar_width = 40
        filled = int(bar_width * self.current / self.total)
        bar = "█" * filled + "░" * (bar_width - filled)
        
        print(f"\r[{bar}] {percent:.1f}% ({self.current}/{self.total}) ETA: {eta:.0f}s", end="", flush=True)
    
    def finish(self):
        print("\n✅ Complete!")
```

**Usage:**
```python
def handle_batch_convert(args):
    files = glob.glob(args.pattern)
    progress = ProgressReporter(len(files))
    
    for file in files:
        convert(file)
        progress.update()
    
    progress.finish()
```

**Output:**
```
[████████████████████░░░░░░░░░░░░░░░░░░░] 52.3% (23/44) ETA: 12s
```

---

## 🧪 AUTOMATED TEST SUITE

**Test script:**
```bash
#!/bin/bash
# test_feature_6.sh

set -e

echo "=== Feature 6: Batch Operations Tests ==="

# Setup
mkdir -p test_batch/{input,converted,exported}

# Test 1: Batch convert WAV
echo "Test 1: Batch convert 10 WAV files..."
for i in {1..10}; do
  ffmpeg -f lavfi -i "sine=$((440+i*10)):d=0.5" -ar 44100 test_batch/input/sample_$i.wav -y 2>/dev/null
done

cli-anything-emaxforge batch-convert \
  --pattern "test_batch/input/*.wav" \
  --output-dir "test_batch/converted" \
  --target-rate 42000 \
  --progress

COUNT=$(ls test_batch/converted/*.wav 2>/dev/null | wc -l)
[ "$COUNT" -eq 10 ] && echo "✅ PASS" || echo "❌ FAIL (got $COUNT, expected 10)"

# Test 2: Batch import banks
echo "Test 2: Batch import banks..."
cli-anything-emaxforge create-disk --size 239 --output test_batch/disk.hda

cli-anything-emaxforge batch-import-banks \
  --disk test_batch/disk.hda \
  --pattern "~/clawd/standard/*.EB2" \
  --progress

BANK_COUNT=$(cli-anything-emaxforge list-banks test_batch/disk.hda --json | jq '.count')
[ "$BANK_COUNT" -gt 0 ] && echo "✅ PASS ($BANK_COUNT banks)" || echo "❌ FAIL"

# Test 3: Batch export banks
echo "Test 3: Batch export all banks..."
cli-anything-emaxforge batch-export-banks \
  --disk test_batch/disk.hda \
  --output-dir test_batch/exported \
  --progress

EXPORT_COUNT=$(ls test_batch/exported/*.EB2 2>/dev/null | wc -l)
[ "$EXPORT_COUNT" -eq "$BANK_COUNT" ] && echo "✅ PASS" || echo "❌ FAIL"

# Test 4: Round-trip validation
echo "Test 4: Round-trip (export → import)..."
cli-anything-emaxforge create-disk --size 239 --output test_batch/roundtrip.hda

cli-anything-emaxforge batch-import-banks \
  --disk test_batch/roundtrip.hda \
  --pattern "test_batch/exported/*.EB2"

RT_COUNT=$(cli-anything-emaxforge list-banks test_batch/roundtrip.hda --json | jq '.count')
[ "$RT_COUNT" -eq "$BANK_COUNT" ] && echo "✅ PASS" || echo "❌ FAIL"

echo "✅ ALL TESTS COMPLETE"
```

---

## 🔗 GUI Integration

**SwiftUI View:**
```swift
// Sources/Views/BatchOperationsSheet.swift

struct BatchOperationsSheet: View {
    @State private var operation: BatchOperation = .convertWAV
    @State private var selectedFiles: [URL] = []
    @State private var progress: Double = 0.0
    @State private var isProcessing = false
    
    enum BatchOperation {
        case convertWAV
        case importBanks
        case exportBanks
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Picker("Operation", selection: $operation) {
                Text("Convert WAV Files").tag(BatchOperation.convertWAV)
                Text("Import Banks").tag(BatchOperation.importBanks)
                Text("Export All Banks").tag(BatchOperation.exportBanks)
            }
            .pickerStyle(.segmented)
            
            if operation != .exportBanks {
                Button("Select Files...") {
                    selectFiles()
                }
                
                Text("\(selectedFiles.count) files selected")
                    .foregroundColor(.secondary)
            }
            
            if isProcessing {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(.linear)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Start") {
                    Task {
                        await performBatchOperation()
                    }
                }
                .disabled(isProcessing || (operation != .exportBanks && selectedFiles.isEmpty))
            }
        }
        .padding()
        .frame(width: 500, height: 300)
    }
    
    func performBatchOperation() async {
        isProcessing = true
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/cli-anything-emaxforge")
        
        switch operation {
        case .convertWAV:
            process.arguments = [
                "batch-convert",
                "--pattern", selectedFiles.map(\.path).joined(separator: " "),
                "--output-dir", "converted/",
                "--progress"
            ]
        case .importBanks:
            process.arguments = [
                "batch-import-banks",
                "--disk", currentDisk.path,
                "--pattern", selectedFiles.map(\.path).joined(separator: " "),
                "--progress"
            ]
        case .exportBanks:
            process.arguments = [
                "batch-export-banks",
                "--disk", currentDisk.path,
                "--output-dir", "exported/",
                "--progress"
            ]
        }
        
        // Monitor progress via stdout
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try? process.run()
        
        // Parse progress from output
        for await line in pipe.fileHandleForReading.bytes.lines {
            if let percent = parseProgress(line) {
                progress = percent / 100.0
            }
        }
        
        process.waitUntilExit()
        isProcessing = false
        progress = 1.0
    }
}
```

---

## 🤖 APPLESCRIPT GUI TESTING

```applescript
-- test_feature_6_gui.scpt

tell application "EmaxForge"
    activate
end tell

delay 2

tell application "System Events"
    tell process "EmaxForge"
        -- Open Batch Operations
        keystroke "b" using {command down, shift down}
        delay 1
        
        -- Select "Import Banks"
        click menu button "Operation"
        click menu item "Import Banks"
        
        -- Select files (simulated)
        click button "Select Files..."
        delay 1
        keystroke "g" using {command down, shift down} -- Go to folder
        keystroke "~/clawd/standard"
        keystroke return
        keystroke "a" using command down -- Select all
        keystroke return
        
        -- Start batch import
        click button "Start"
        
        -- Wait for completion (monitor progress)
        repeat until exists (button "Done" of window 1)
            delay 2
        end repeat
        
        -- Screenshot
        do shell script "/usr/sbin/screencapture ~/batch_complete.png"
    end tell
end tell
```

---

## ✅ SUCCESS CRITERIA

**Feature 6 complete when:**
- ✅ Batch convert WAV (10+ files)
- ✅ Batch import banks (50+ banks)
- ✅ Batch export banks (all banks from disk)
- ✅ Progress reporting working (real-time %)
- ✅ Round-trip validation (export → import = identical)
- ✅ GUI integrated (BatchOperationsSheet)
- ✅ AppleScript automation successful

**Timeline:** 3-4 hours

**Next:** Feature 8 (Error Codes) or Feature 7 (Loop Editor)
