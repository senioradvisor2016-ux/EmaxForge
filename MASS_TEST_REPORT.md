# Mass Parser Test — Universe of Sounds 1

**Date:** 2026-03-17 07:30 CET  
**Target:** Universe of Sounds 1 (504 banks)  
**Parser:** `cli-parse-bank.swift`  
**Runtime:** ~2 minutes

---

## Summary

**Total banks:** 504  
**Successfully parsed:** 504 (100%)  
**Failed:** 0

**Result:** Parser handles all 504 factory banks! ✅

---

## Pointer Count Distribution

| Count | Banks | Percentage |
|-------|-------|------------|
| 100 | 457 | 90.7% |
| 80 | 11 | 2.2% |
| 64 | 2 | 0.4% |
| 44 | 9 | 1.8% |
| 40 | 2 | 0.4% |
| 28 | 1 | 0.2% |
| 16 | 1 | 0.2% |
| 8 | 12 | 2.4% |
| 4 | 2 | 0.4% |
| 0 | 1 | 0.2% |

**Key Insight:** 90.7% of banks use 100 voices (max capacity!)

---

## File Size Distribution

| Size (MB) | Banks | Percentage |
|-----------|-------|------------|
| <1 | 490 | 97.2% |
| 1-2 | 14 | 2.8% |

**Average size:** ~800 KB per bank  
**Largest bank:** 1.07 MB (Baby_Grand.EB2)

---

## Bank Names

### Most Common Pattern:
**"T> 1 TEXTURE PAD A"** — 385 banks (76.4%)!

**Analysis:**
- This pattern suggests **corrupted/incorrectly parsed name field**
- Likely parser bug: Reading wrong offset or structure
- Name field offset varies by bank format?

### Valid Names (119 banks, 23.6%):
- PLAIN (7 banks)
- PLAIN 1 (2 banks)
- Yamaha C3 88 (1 bank)
- VCS 2 PLAIN (1 bank)
- + 114 unique names

---

## Edge Cases Discovered

### 1. Zero Pointers (1 bank)
**File:** `12_String_Guitarand_Voices.EB2`  
**Size:** 972 KB  
**Pointers:** 0

**Possible causes:**
- Empty/corrupted bank
- Sequence data only (no samples?)
- Special format (multi-disk part?)

---

### 2. Low Pointer Count (< 40)

| Bank | Pointers | Size |
|------|----------|------|
| Beef_Drums.EB2 | 64 | <1 MB |
| Rock_Organ_2.EB2 | 44 | <1 MB |
| Wurly_Electric_Piano | 28 | <1 MB |

**Hypothesis:** Simple banks with fewer samples/voices

---

### 3. Corrupted Bank Names (385 banks!)

**Pattern:** `T>   1 TEXTURE PAD A` (with control chars)

**Examples:**
- Rin_Martin.EB2 → "T>   1 TEXTURE PAD A"
- Library_Combo.EB2 → "T>   1 TEXTURE PAD A"
- Celli_Tremolande.EB2 → "T>   1 TEXTURE PAD A"

**Root Cause:** Parser reading wrong name offset!

**Current logic:**
```swift
// Scan for ASCII string starting with capital letter
for offset in stride(from: 0x100, to: Swift.min(0x300, data.count - 16), by: 1) {
    let testName = data.readString(at: offset, length: 16)
    if !testName.isEmpty && testName.count >= 4 {
        if let first = testName.first, first.isUppercase {
            bankName = testName
            bankNameOffset = offset
            break  // ← Takes FIRST match, not BEST match!
        }
    }
}
```

**Problem:** First match = wrong match!

**Fix:** Improve heuristics:
1. Check for printable ASCII (no control chars)
2. Prefer names with spaces (real names)
3. Validate against common patterns
4. Use actual bank name offset from structure

---

## Top 10 Largest Banks

| Rank | Bank | Size | Notes |
|------|------|------|-------|
| 1 | Baby_Grand.EB2 | 1.07 MB | Piano |
| 2 | Female_Voices_and_Synth.EB2 | 1.07 MB | Vocals + Synth |
| 3 | Accordion_Bass.EB2 | 1.07 MB | Accordion |
| 4 | Star_Travel.EB2 | 1.07 MB | Space SFX |
| 5 | Multi_Synth_Combo.EB2 | 1.07 MB | Synth stack |
| 6 | Grand_Piano_2.EB2 | 1.07 MB | Piano |
| 7 | Expensive_Synth_Stack.EB2 | 1.07 MB | Synth stack |
| 8 | Fretless_Bass_and_Piano.EB2 | 1.07 MB | Bass + Piano |
| 9 | Smoke_Piano.EB2 | 1.06 MB | Piano |
| 10 | Kyodai_Synth_Collage.EB2 | 1.06 MB | Synth collage |

**Pattern:** All ~1.07 MB (max bank size?)

---

## Parser Issues Found

### 🐛 Issue #1: Bank Name Offset Wrong (76% affected!)

**Symptom:** 385 banks return "T> 1 TEXTURE PAD A" with control chars

**Root cause:** Parser scans 0x100-0x300, takes FIRST uppercase string

**Fix needed:**
1. Better heuristics (printable chars, spaces)
2. Read actual name from structure (not scan)
3. Fallback to filename if name invalid

---

### ⚠️ Issue #2: Zero Pointers Not Handled

**Symptom:** 1 bank with 0 pointers (12_String_Guitarand_Voices.EB2)

**Fix needed:**
1. Check if bank is empty/corrupt
2. Parse sequence data separately?
3. Handle multi-disk banks

---

### ⚠️ Issue #3: Voice Parsing Not Implemented

**Current:** Only pointer count estimated, no actual voice data

**Fix needed:**
1. Parse voice structure (zones, samples)
2. Extract sample metadata
3. Validate sample data pointers

---

## Next Steps

### Immediate Fixes:
1. **Fix bank name parser** (Issue #1)
   - Better heuristics
   - Read from structure
   - Validate printable ASCII

2. **Handle zero-pointer banks** (Issue #2)
   - Detect empty/corrupt
   - Special case handling

### Next Phase (Voice Parsing):
1. Parse voice structure from pointer table
2. Extract zone data (key ranges, velocity)
3. Parse sample metadata (rate, length, loop points)
4. Validate sample data integrity

### Future Testing:
1. **X_Convert (1,431 banks)** — SF2 conversions
2. **Drums (142 banks)** — Percussion specialization
3. **Alan Wilder (34 banks)** — Real-world complexity
4. **Full collection (2,877 banks)** — Complete validation

---

## Conclusions

### ✅ Successes:
- Parser handled 504 banks without crashes
- Pointer count distribution matches expectations (90.7% @ 100 voices)
- Edge cases identified (0 pointers, low counts)

### ❌ Issues:
- Bank name parsing incorrect (76% failure rate!)
- Voice structure not parsed yet
- Sample data not extracted

### 📊 Data Quality:
- 504 banks parsed = Solid test coverage
- Edge cases found = Parser improvement opportunities
- Statistics = Format understanding deepened

---

## Test Data Summary

**Raw results:** `results_20260317_073056.jsonl` (504 entries)  
**Statistics:** `stats_20260317_073056.txt`

**Query examples:**
```bash
# List all banks with <40 pointers
jq 'select(.pointers < 40)' results_*.jsonl

# Count banks by pointer count
jq -r '.pointers' results_*.jsonl | sort | uniq -c

# Find largest banks
jq -r '[.filename, .size] | @tsv' results_*.jsonl | sort -k2 -rn | head -10
```

---

**Next:** Fix bank name parser, then implement voice/sample parsing! 🚀
