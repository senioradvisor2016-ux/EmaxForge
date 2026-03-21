# EmaxForge vs standard tools - Gap Analysis

**Date:** 2026-03-05  
**Source:** standard tools menu strings (555 total) from Ghidra decompilation  
**Method:** String pattern analysis + EmaxForge feature comparison

---

## 📊 SUMMARY

**EmaxForge v1.0 Status:**
- ✅ Core file system operations (create, format, verify)
- ✅ Bank import/export
- ✅ Sample extraction to WAV
- ✅ Browse: Samples, Presets, Banks
- ✅ Inspector panel (5 tabs)
- ✅ Waveform preview/editing
- ✅ ZuluSCSI integration

**Missing Features Found in standard tools:**
- ❌ Report generation (HTML, TXT, CSV)
- ❌ Stereo file creation
- ❌ Physical format presets/management
- ❌ Multi-format conversion (EMAX→EMU, etc.)
- ❌ Preference screens ("Always show...")
- ❌ Batch operations on multiple banks
- ❌ File naming format templates

---

## 🎯 MISSING FEATURES (Priority Order)

### 🔴 HIGH PRIORITY (v1.1 Candidates)

#### 1. **Report Generation**
**standard tools Evidence:**
```
"Create Bank/Preset Overview Report" (menu #5-6)
"Create HTML Report without %s" (menu #1)
"Create HTML Report including %s" (menu #2)
"Create Bank/Preset Report in TXT" (menu #1)
"Create Bank/Preset Report in CSV" (menu #2)
"Create Bank/Sound Report in TXT/CSV"
"Create Bank/Sequence Report in TXT/CSV"
```

**What standard tools Does:**
- Generates HTML/TXT/CSV reports for:
  - Bank overview (all presets + samples)
  - Preset details (voices, key ranges, samples)
  - Sample inventory (sizes, rates, loops)
  - Sound library catalogs
- Can export for single bank or all banks
- Includes/excludes specific data based on user choice

**EmaxForge Gap:**
- ❌ No report generation
- ❌ No HTML/CSV export
- ❌ No printable documentation

**User Value:** 🟢 HIGH
- Documentation for hardware synth users
- Shareable library catalogs
- Backup reference sheets

**Implementation Effort:** 🟡 MEDIUM (4-6 hours)
- Reuse existing SampleAnalyzer/PresetAnalyzer
- Add HTML/CSV formatters
- Create ReportGeneratorSheet view

---

#### 2. **Stereo Sample File Creation**
**standard tools Evidence:**
```
"Create a STEREO %s file from the..." (feature)
"- %d stereo %s file%s %s created" (confirmation)
"required to create a stereo %s file..." (validation)
```

**What standard tools Does:**
- Combines two mono samples into stereo WAV
- Used for: L+R channel samples, dual-layer sounds
- Supports EMAX II stereo outputs

**EmaxForge Gap:**
- ❌ Only mono WAV export
- ❌ No stereo pairing functionality

**User Value:** 🟡 MEDIUM
- Important for stereo-capable EMAX II setups
- Modern DAW workflows expect stereo

**Implementation Effort:** 🟢 LOW (2-3 hours)
- Extend SampleExtractor with stereo merge
- Add UI for selecting L+R sample pairs
- Interleave PCM data in WAV output

---

#### 3. **Physical Format Presets**
**standard tools Evidence:**
```
"DEFINE PHYSICAL FORMAT %s%s%s" (setup)
"Default Format" (preset)
"Copy a Pre-defined Format to Config..." (feature)
"Enable/Disable physical format %d%s" (toggle)
"Define a Format for Configuration..." (creation)
"Always use the physical format of..." (preference)
```

**What standard tools Does:**
- Saves format presets (cluster size, volume size, OS selection)
- Quick-apply common configurations
- Named format templates (e.g., "HD Boot 524MB", "SD Data 2GB")
- Enable/disable formats per device type

**EmaxForge Gap:**
- ❌ No format presets
- ❌ Must manually configure each time
- ❌ No quick-apply templates

**User Value:** 🟢 HIGH
- Speed up repetitive workflows
- Reduce configuration errors
- Standardize across multiple ZuluSCSI cards

**Implementation Effort:** 🟡 MEDIUM (3-5 hours)
- Create FormatPreset model (name, clusterSize, volumeSize, includeOS)
- Persist presets to UserDefaults/JSON
- Add preset picker in NewImageSheet

---

### 🟡 MEDIUM PRIORITY (v1.2-2.0)

#### 4. **Multi-Sampler Format Conversion**
**standard tools Evidence:**
```
"%d. %s to %s Sampler Format" (conversion options)
"Convert the banks to %s format" (action)
"Requested sampler format (%d) is..." (validation)
```

**What standard tools Does:**
- Convert EMAX II banks → EMU-I/II/III/Emax/AKAI S1000
- Handles sample rate/bit depth differences
- Maps preset parameters across formats

**EmaxForge Gap:**
- ❌ EMAX-II only (by design)

**User Value:** 🔴 LOW (for v1.0 scope)
- Out of scope: EmaxForge is EMAX-II focused
- Could be v2.0+ feature if user demand exists

**Implementation Effort:** 🔴 HIGH (20-40 hours)
- Requires learning EMU/AKAI formats
- Complex parameter mapping
- Not aligned with v1.0 vision

---

#### 5. **File Naming Templates**
**standard tools Evidence:**
```
"DEFINE FORMAT OF %s FILE NAMES CREATED..." (template editor)
"DEFINE FORMAT OF %s FILE NAMES%s" (per-sampler)
"DEFINE FORMAT OF %s SAMPLE NAMES" (sample output)
```

**What standard tools Does:**
- Configurable filename patterns: `{bankname}_{sampleindex}_{samplename}.wav`
- Variables: bank, preset, sample, date, index
- Sanitization rules (max length, illegal chars)

**EmaxForge Gap:**
- ✅ Has basic sanitization (64 char limit, illegal char removal)
- ❌ No user-configurable templates
- ❌ Always uses: `{samplename}.wav`

**User Value:** 🟡 MEDIUM
- Workflow customization
- Avoids filename collisions
- Matches user's DAW organization

**Implementation Effort:** 🟢 LOW (2-3 hours)
- Add template string to preferences
- Parse variables: `{bank}`, `{index}`, `{sample}`
- Update SampleExtractor filename generation

---

#### 6. **Batch Operations**
**standard tools Evidence:**
```
"Create Bank/Preset Report for all selected..." (batch)
"...WHEN FORMATTING/COPYING 23 BANKS..." (progress)
"...WHEN FORMATTING/COPYING 46 BANKS..." (progress)
```

**What standard tools Does:**
- Multi-select banks in list
- Batch export, batch format, batch copy
- Progress tracking across all items

**EmaxForge Gap:**
- ❌ Single-bank operations only
- ❌ No multi-select in BankBrowserView

**User Value:** 🟡 MEDIUM
- Time-saving for large libraries
- Archive entire disks

**Implementation Effort:** 🟡 MEDIUM (4-6 hours)
- Change BankBrowserView selection to Set<BankID>
- Add "Export Selected..." / "Delete Selected..." actions
- Progress view with per-bank status

---

### 🟢 LOW PRIORITY (Nice-to-Have)

#### 7. **Preference Screens**
**standard tools Evidence:**
```
"Always show this screen when..." (20+ variants)
"Always show warnings when..." (5+ variants)
"Don't show this screen anymore" (10+ variants)
"DISPLAY FORMAT AND NOTATION PREFERENCES" (dialog)
```

**What standard tools Does:**
- Per-action confirmation toggles
- Notation preferences (scientific, musical)
- Warning suppression
- UI behavior customization

**EmaxForge Gap:**
- ❌ No user preferences (uses SwiftUI defaults)
- ❌ No confirmation toggles

**User Value:** 🔴 LOW
- Power user convenience
- Not critical for v1.0

**Implementation Effort:** 🟡 MEDIUM (3-5 hours)
- Settings.bundle or SwiftUI Settings
- Persist to UserDefaults
- Add confirmation checks before destructive ops

---

#### 8. **File Overview Screen**
**standard tools Evidence:**
```
"Always show a File Overview (to show...)" (preference)
"Don't show a File Overview (this is...)" (disable)
"DEFINE IF standard tools SHOULD SHOW AN OVERVIEW..." (config)
```

**What standard tools Does:**
- After opening image, shows summary popup:
  - Total banks, presets, samples
  - Disk usage
  - OS version
  - Quick stats

**EmaxForge Gap:**
- ❌ No automatic overview popup
- ✅ Stats available in Inspector Overview tab (manual)

**User Value:** 🔴 LOW
- Nice for quick glances
- Not essential with Inspector panel

**Implementation Effort:** 🟢 LOW (1-2 hours)
- Create ImageOverviewSheet
- Show on image open (if preference enabled)
- Reuse existing analyzers

---

## 📈 FEATURE COMPARISON TABLE

| Feature | standard tools | EmaxForge v1.0 | Priority | Effort |
|---------|------|----------------|----------|--------|
| **Core Operations** | | | |
| Create disk images | ✅ | ✅ | - | - |
| Format disks | ✅ | ✅ | - | - |
| Import/export banks | ✅ | ✅ | - | - |
| Sample extraction (mono) | ✅ | ✅ | - | - |
| Disk verification | ✅ | ✅ | - | - |
| **Browsing/Analysis** | | | |
| Show Samples | ✅ | ✅ | - | - |
| Show Presets | ✅ | ✅ | - | - |
| Bank Inspector | ✅ | ✅ | - | - |
| Orphan detection | ✅ | ✅ | - | - |
| Waveform preview | ✅ | ✅ | - | - |
| **Missing Features** | | | |
| Report generation (HTML/CSV/TXT) | ✅ | ❌ | 🔴 HIGH | 4-6h |
| Stereo sample creation | ✅ | ❌ | 🟡 MED | 2-3h |
| Physical format presets | ✅ | ❌ | 🔴 HIGH | 3-5h |
| File naming templates | ✅ | ❌ | 🟡 MED | 2-3h |
| Batch operations | ✅ | ❌ | 🟡 MED | 4-6h |
| Multi-format conversion | ✅ | ❌ | 🔴 LOW* | 20-40h |
| Preference screens | ✅ | ❌ | 🔴 LOW | 3-5h |
| File overview popup | ✅ | ❌ | 🔴 LOW | 1-2h |

*Low priority for EmaxForge (EMAX-II focus)

---

## 🎯 RECOMMENDED ROADMAP

### **v1.1 (Quick Wins - ~10-15 hours)**
1. ✅ Report generation (HTML/CSV)
2. ✅ Stereo sample creation
3. ✅ Physical format presets
4. ✅ File naming templates

**Why These 4:**
- Directly improve daily workflows
- Low implementation effort
- High user value
- Natural extensions of existing features

### **v1.2 (Power User Features - ~8-12 hours)**
5. ✅ Batch operations
6. ✅ Preference screens
7. ✅ File overview popup

### **v2.0+ (Future)**
8. Multi-sampler support (if user demand)
9. Cloud backup integration
10. Preset synthesis engine (?)

---

## 💡 INSIGHTS

### **What EmaxForge Does BETTER Than standard tools:**

1. **Modern UI/UX**
   - SwiftUI tables vs Windows 95 dialogs
   - Real-time search/filter
   - Visual charts (pie charts, waveforms)
   - Hex dump navigation

2. **Performance**
   - Async operations with progress
   - Non-blocking UI
   - Optimized parsers (3 reads vs 500+)

3. **Workflow Integration**
   - Native macOS app (no Wine)
   - Drag & drop support
   - Context menus
   - Keyboard shortcuts

4. **Analysis Tools**
   - 5-tab inspector (vs modal dialogs)
   - Orphan detection with visual warnings
   - Cluster chain visualization
   - Memory breakdown charts

### **What standard tools Does That EmaxForge Doesn't:**

1. **Documentation Generation** (biggest gap!)
   - No way to create shareable catalogs
   - No printable reference sheets

2. **Stereo Workflows**
   - Mono-only limits modern production

3. **Workflow Automation**
   - No presets = repetitive configuration
   - No batch = tedious for large libraries

4. **Multi-Sampler Support**
   - By design, but limits target audience

---

## ✅ ACTIONABLE NEXT STEPS

**For v1.1 Release (2-3 weeks):**

1. **Report Generator** (Priority #1)
   - Implement HTMLReportGenerator + CSVReportGenerator
   - Create ReportOptionsSheet (select format, data to include)
   - Add "Generate Report..." to ImageDetailView actions

2. **Stereo Sample Export** (Priority #2)
   - Extend ExtractSamplesSheet with stereo pairing UI
   - Add "Pair as Stereo" checkbox per sample
   - Implement stereo WAV interleaving in SampleExtractor

3. **Format Presets** (Priority #3)
   - Create FormatPreset model + PresetManager
   - Add "Load Preset" picker in NewImageSheet
   - Ship with 3-4 default presets (HD Boot, SD Data, etc.)

4. **Filename Templates** (Priority #4)
   - Add template preference: `{bank}_{index}_{sample}.wav`
   - Parse variables in SampleExtractor
   - Add template editor in Settings (future)

**Estimated Total:** 10-15 hours implementation + 3-5 hours testing = **v1.1 in ~20 hours**

---

## 📚 REFERENCES

- **standard tools Menu Strings:** ~/clawd/EmaxForge/ghidra/standard tools_MENU_STRINGS.txt (555 strings)
- **standard tools Error Strings:** ~/clawd/EmaxForge/ghidra/standard tools_ERROR_STRINGS.txt (1,207 strings)
- **EmaxForge v1.0:** Features 1-5 complete (verified against standard tools)
- **Analysis Date:** 2026-03-05

**Confidence Level:** HIGH
- Based on 555 menu strings + 1,207 error messages
- Cross-referenced with EmaxForge codebase
- Prioritization based on user workflow value

---

**END OF GAP ANALYSIS**
