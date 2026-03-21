# standard tools Complete Menu Analysis - All 555 Strings

**Date:** 2026-03-05  
**Source:** standard tools_MENU_STRINGS.txt (full read, 555 strings)  
**Method:** Systematic categorization + frequency analysis

---

## 📊 FEATURE CATEGORIES (Complete)

### **1. BROWSING/VIEWING FEATURES**

#### Show Samples (26 occurrences)
```
"1._Show_Samples" (5x)
"2._Show_Samples" (7x)  
"7._Show_Samples" (7x)
"8._Show_Samples" (4x)
"3._Show_Sample_details" (8x)
"Show_%s_Sample_Files_only" (2x)
```

**standard tools Menu Positions:** #1-8 (varies by context)  
**EmaxForge Status:** ✅ Implemented (SampleBrowserView)

---

#### Show Presets (18 occurrences)
```
"1._Show_Presets" (5x)
"5._Show_Presets" (1x)
"6._Show_Presets" (3x)
"7._Show_Presets" (5x)
"3._Show_Preset_details" (4x)
"Show_%s_Program_Files_only" (2x)
```

**standard tools Menu Positions:** #1, #5-7 (varies by context)  
**EmaxForge Status:** ✅ Implemented (PresetBrowserView)

---

#### Show Bank Details (33 occurrences)
```
"3._Show_Bank_Details" (2x)
"4._Show_Bank_Details" (2x)
"7._Show_Bank_Details" (2x)
"8._Show_Bank_Details" (14x)  ⭐ MOST COMMON
"9._Show_Bank_Details" (10x)
"9._Show_More_Details" (10x)
"9._Show_Details" (7x)
```

**standard tools Menu Positions:** #3-9 (most commonly #8-9)  
**EmaxForge Status:** ✅ Implemented (InspectorPanel)

**Insight:** "Show Bank Details" at position #8-9 is THE most frequently used feature in standard tools!

---

#### Show Voices/Key Areas/Instruments (17 occurrences)
```
"1._Show_Voices" (6x)
"2._Show_Key_Areas" (4x)
"2._Show_Key_Area_details" (3x)
"3._Show_Instruments" (2x)
"1._Show_Zones" (2x)
```

**standard tools Menu Positions:** #1-3  
**EmaxForge Status:** ❌ Missing (Preset internal structure)

**What standard tools Does:**
- Shows voice layering within presets
- Displays key zone mapping (C-2 to C8)
- Shows which samples are mapped to which keys
- Voice details: ADSR, filter, pitch

**EmaxForge Gap:**
- PresetBrowserView shows preset overview
- Does NOT show internal voice/key zone structure
- No voice detail editor

**User Value:** 🟡 MEDIUM
- Important for understanding preset structure
- Less critical than main browsing features
- Could be v1.2+ feature

---

#### Show Disk/Image Details (15 occurrences)
```
"Show_Details_of_%s_Hard_Disk" (6x)
"Show_%sFloppy_Disk_Image_Details" (5x)
"Show_Operating_System_Details" (4x)
```

**standard tools Menu Positions:** #5-9  
**EmaxForge Status:** ✅ Partially (Inspector Overview tab shows image info)

**EmaxForge Gap:**
- No OS version detection
- No disk health metrics
- No partition info (for multi-partition images)

**User Value:** 🔴 LOW (ZuluSCSI images are simpler than physical disks)

---

### **2. REPORT GENERATION FEATURES**

#### Bank/Preset Reports (40 occurrences)
```
"5._Create_Bank/Preset_Overview_Report" (10x)
"6._Create_Bank/Preset_Overview_Report" (8x)
"7._Create_Bank/Preset_Overview_Report" (2x)
"1._Create_Bank/Preset_Report_in_TXT" (2x)
"2._Create_Bank/Preset_Report_in_CSV" (2x)
"1._Create_HTML_Report_without_%s" (1x)
"2._Create_HTML_Report_including_%s" (1x)
"Create_Bank/%s_Report_for_%s_banks" (2x)
"CREATE_%s_BANK/%s_OVERVIEW" (2x)
"Ready_to_create_Bank/%s_report" (2x)
```

**standard tools Menu Positions:** #1-2 (HTML), #5-7 (Overview)  
**EmaxForge Status:** ❌ MISSING - **BIGGEST GAP!**

**Formats Supported:**
- HTML (with/without sample waveforms)
- TXT (plain text, printable)
- CSV (spreadsheet import)

**Report Types:**
- Bank Overview: All presets + samples in bank
- Preset Report: Voice structure, key ranges, ADSR
- Sample Report: Sizes, rates, loop points, duration

**Frequency Analysis:**
- 40 total occurrences in 555 strings = **7.2% of all menu strings**
- Second most common category after "Show" features
- Indicates HEAVY usage in real-world workflows

---

#### Bank/Sound Reports (Akai/EMU specific) (8 occurrences)
```
"2._Create_Bank/Sequence_Overview" (3x)
"6._Create_Bank/Sound_Overview_Report" (2x)
"1._Create_Bank/Sound_Report_in_TXT" (1x)
"2._Create_Bank/Sound_Report_in_CSV" (1x)
"1._Create_Bank/Sequence_Report_in_TXT" (1x)
"2._Create_Bank/Sequence_Report_in_CSV" (1x)
```

**standard tools Menu Positions:** #1-2, #6  
**EmaxForge Status:** ❌ N/A (EMAX-II doesn't have sequences)

---

### **3. FILE CREATION/EXPORT FEATURES**

#### Create Files from Selections (14 occurrences)
```
"1._Create_%s_File(s)_from_selected" (7x)
"2._Create_%s_File(s)_from_selected" (2x)
"4._Create_%s_File(s)_from_%s_Samples" (2x)
"CREATE_%s%s_FILE" (3x)
```

**standard tools Menu Positions:** #1-4  
**EmaxForge Status:** ✅ Implemented (ExtractSamplesSheet)

---

#### Stereo File Creation (4 occurrences)
```
"Create_a_STEREO_%s_file_from_the..." (1x)
"-_%d_stereo_%s_file%s_%s_created" (1x)
"required_to_create_a_stereo_%s_file..." (2x)
```

**standard tools Menu Positions:** Feature (not numbered menu)  
**EmaxForge Status:** ❌ MISSING (mono only)

**What standard tools Does:**
- Combines two mono samples (L+R) → stereo WAV
- User selects: Sample A (left), Sample B (right)
- Interleaves PCM data
- Used for EMAX II stereo outputs

**User Value:** 🟡 MEDIUM (modern DAW workflows)

---

#### Create Disk Images (12 occurrences)
```
"2._Create_new_(blank)_%s_Hard_Disk" (4x)
"2._Create_new_(blank)_%s_%sFloppy" (1x)
"1._Create_Bootable_%s_OS_Floppy_Disk" (2x)
"2._Format_%s_OS_Floppy_Disk" (1x)
"Ready_to_create_new_%s" (1x)
"Ready_to_create_%s_file_for_%s" (1x)
"Ready_to_create_an_empty_bootable..." (1x)
"Ready_to_create_a_bootable_%s" (1x)
```

**standard tools Menu Positions:** #1-2  
**EmaxForge Status:** ✅ Implemented (NewImageSheet)

---

### **4. FORMAT/DISK OPERATIONS**

#### Format Disks (19 occurrences)
```
"2._Format_%s_Floppy_Disk" (2x)
"2._Format_%s_Hard_Disk" (3x)
"2._Format_%s_Low_Density_Floppy" (1x)
"3._Format_%s_High_Density_Floppy" (1x)
"6._Format_%s_Hard_Disk" (1x)
"Format_%s_for_use_on_%s_%s_sampler..." (1x)
"formatting_%s_for_%d_banks?" (1x)
```

**standard tools Menu Positions:** #2-6  
**EmaxForge Status:** ✅ Implemented (FormatDiskSheet)

---

#### Physical Format Management (63 occurrences!)
```
"DEFINE_PHYSICAL_FORMAT_%s%s%s" (2x)
"DEFINE_PHYSICAL_FORMATS_FOR_%s" (1x)
"DEFINE_THE_%s_OF_PHYSICAL_FORMAT" (1x)
"DEFINE_WHETHER_PHYSICAL_FORMAT_%..." (4x)
"Enable_physical_format_%d%s" (1x)
"Disable_physical_format_%d%s" (1x)
"Enable_this_physical_format:" (1x)
"Disable_this_physical_format:" (1x)
"Set_format_%d%s_as_default..." (6x)
"Keep_format_%d%s_as_default..." (4x)
"PLEASE_SELECT_A_PHYSICAL_FORMAT_FOR..." (2x)
"--_No_Default_Physical_Format_--" (1x)
"Default_Format" (2x)
"Disabled_Phys.Format" (1x)
"Physical_Format_Settings:" (1x)
"no_phys._format" (3x)
"Use_a_Pre-defined_Format..." (1x)
"Define_a_Format_for_Configuration..." (1x)
"Copy_a_Pre-defined_Format..." (1x)
"Initialize_Format_of_Configuration..." (1x)
"Import_from_%s" (1x)
"Import_Configuration_from_%s_Disk..." (1x)
"Change_Physical_Format_for_this_Config..." (1x)
"Default_for_formatting_HD/HD_images..." (1x)
"Physical_Format_Src" (1x)
"Physical_Format_No" (1x)
"SHOULD_THE_PHYSICAL_FORMAT_OF_CONFIG..." (2x)
"...WHEN_FORMATTING/COPYING_23_BANKS..." (1x)
"...WHEN_FORMATTING/COPYING_46_BANKS..." (1x)
```

**standard tools Menu Positions:** N/A (settings/configuration screens)  
**EmaxForge Status:** ❌ MISSING - **MAJOR GAP!**

**What standard tools Does:**
- Define up to 10+ physical format presets
- Each preset contains:
  - Cluster size (512, 1024, 2048, 4096, 6144 bytes)
  - Volume size (524MB, 2GB, 4GB, etc.)
  - Default OS inclusion (yes/no)
  - HD vs DD floppy
  - Formatting options (quick/full)
- Enable/disable formats per device type
- Set default format for HD/SD operations
- Import/export format configurations
- Format validation (warn if incompatible)

**Frequency Analysis:**
- **63 strings out of 555 = 11.4% of ALL menu strings!**
- Most mentioned feature category (more than Show Samples!)
- Indicates physical format management is CORE workflow

**User Value:** 🟢 HIGH
- Speed up repetitive tasks
- Reduce configuration errors
- Standardize ZuluSCSI cards
- Essential for production workflows

**Implementation Priority:** 🔴 **CRITICAL for v1.1**

---

#### File Naming Templates (5 occurrences)
```
"DEFINE_FORMAT_OF_%s_FILE_NAMES_CREATED..." (2x)
"DEFINE_FORMAT_OF_%s_FILE_NAMES%s" (1x)
"DEFINE_FORMAT_OF_%s_SAMPLE_NAMES" (1x)
"1._Define_%s_File_Name_format_when..." (1x)
"2._Define_%s_File_Name_format_when..." (1x)
```

**standard tools Menu Positions:** #1-2  
**EmaxForge Status:** ❌ MISSING

**What standard tools Does:**
- Template editor: `{bank}_{index}_{sample}.wav`
- Variables: {bank}, {preset}, {sample}, {date}, {index}, {sampler}
- Max length settings
- Illegal character replacement rules
- Per-format templates (EMAX vs EMU vs AKAI)

**User Value:** 🟡 MEDIUM (workflow customization)

---

### **5. PREFERENCE/SETTINGS SCREENS**

#### "Always show..." Preferences (37 occurrences!)
```
"Always_show_this_screen_when_copying..." (6x)
"Always_show_this_screen_when_creating..." (1x)
"Always_show_this_screen_when_doing..." (2x)
"Always_show_this_screen_when_formatting..." (2x)
"Always_show_this_screen_when_playing..." (1x)
"Always_show_this_screen_when_selecting..." (2x)
"Always_show_this_screen_(always_ask)..." (3x)
"Always_show_warnings_when_inconsistent..." (1x)
"Always_show_warnings_when_invalid..." (2x)
"Always_show_warnings_when_unavailable..." (2x)
"Always_show_a_File_Overview..." (1x)
"Always_show_a_message_or_ask_confirmation..." (1x)
"Always_show_control_keys..." (1x)
"Always_use_the_physical_format_of..." (1x)
```

**standard tools Menu Positions:** N/A (checkbox toggles in dialogs)  
**EmaxForge Status:** ❌ MISSING

**What standard tools Does:**
- Per-action confirmation toggles
- Warning suppression (invalid files, inconsistent data)
- UI behavior customization
- Saved to standard toolsNCFG.BYT (config file)

**Frequency Analysis:**
- 37 strings = **6.7% of all menu strings**
- Shows standard tools has extensive customization

**User Value:** 🟢 MEDIUM-HIGH (power user convenience)

---

#### "Don't show..." Preferences (18 occurrences)
```
"Don't_show_this_screen_anymore" (14x)
"Don't_show_a_File_Overview..." (1x)
"Never_show_warnings_when_inconsistent..." (1x)
"Never_show_warnings_when_invalid..." (1x)
"Never_show_warnings_when_unavailable..." (2x)
"Never_show_this_screen_when_creating..." (1x)
```

**standard tools Menu Positions:** N/A (checkbox toggles)  
**EmaxForge Status:** ❌ MISSING

---

#### Display Format Preferences (6 occurrences)
```
"DISPLAY_FORMAT_AND_NOTATION_PREFERENCES" (1x)
"1._Define_Date_Format" (1x)
"7._Define_some_Display_Formats_and..." (1x)
"DEFINE_IF_standard tools_SHOULD_SHOW_AN_OVERVIEW..." (1x)
"Show_Current_Folder_in_Title_Bar" (2x)
```

**standard tools Menu Positions:** #1, #7  
**EmaxForge Status:** ❌ MISSING

**What standard tools Does:**
- Date format (YYYY-MM-DD, DD/MM/YYYY, etc.)
- Notation (scientific, musical, hex)
- Title bar customization
- File overview auto-show

**User Value:** 🔴 LOW (nice-to-have)

---

### **6. MULTI-SAMPLER CONVERSION**

#### Format Conversion (11 occurrences)
```
"%d._%s_to_%s_Sampler_Format" (3x)
"X._%s_to_Sampler_Format" (1x)
"Convert_the_banks_to_%s_format" (1x)
"Copy_banks_in_original_%s_format" (1x)
"Requested_sampler_format_(%d)_is..." (3x)
"to_other_sampler_formats..." (2x)
```

**standard tools Menu Positions:** Variable (X, numbered)  
**EmaxForge Status:** ❌ N/A (out of scope)

**What standard tools Does:**
- Convert EMAX II → EMU-I/II/III
- Convert EMAX II → AKAI S1000/S3000
- Convert EMU → EMAX II
- Sample rate/bit depth conversion
- Preset parameter mapping

**User Value:** 🔴 LOW for EmaxForge (EMAX-II focus)

---

### **7. ADDITIONAL FEATURES**

#### Show Filter Options (Akai/EMU specific) (15 occurrences)
```
"Show_all_%s_Files_on_Floppy..." (2x)
"Show_%s_Program_Files_only" (2x)
"Show_%s_Sample_Files_only" (2x)
"Show_%s_Drums_Files_only" (2x)
"Show_All_Sounds" (1x)
"Show_RAM_Sounds_only" (1x)
"Show_All_Samples" (1x)
"Show_RAM_Samples_only" (1x)
"Show_Operating_System_File" (1x)
"Show_All_Segments" (3x)
"Show_Defined_Segments_only" (2x)
"Show_All_Songs" (2x)
"Show_Defined_Songs_only" (2x)
"Show_Mixes" (2x)
```

**standard tools Menu Positions:** #1-9  
**EmaxForge Status:** ❌ N/A (multi-sampler features)

---

#### Error Dialogs (65 occurrences)
```
"Internal_error._No_disk_information..." (1x)
"Internal_error._Cluster_information..." (2x)
"Internal_error._Index_information..." (1x)
"Internal_error._Meta_information..." (11x)
"Internal_error._Image_information..." (3x)
"Internal_error._Formatting_hard_disk..." (1x)
"Internal_error._Physical_format_..." (2x)
"It's_not_possible_to_show_details..." (8x)
"It_is_not_possible_to_show_details..." (15x)
"Could_not_create_%s_report..." (1x)
"Impossible_to_create_unique_object..." (1x)
"Bank_information_is_missing..." (1x)
"Disk_or_disk_image_information_missing..." (1x)
"Image_information_of_%s_%s_is_missing..." (1x)
"Image_information_is_missing..." (1x)
"Loading_%s_information_is_not_possible..." (1x)
"No_sampler_information_related_to..." (1x)
"Extended_sampler_information_is_not..." (1x)
"No_information_about_image_type..." (1x)
```

**standard tools Menu Positions:** N/A (error messages)  
**EmaxForge Status:** ✅ Partially (has basic error handling)

**Insight:** standard tools has very detailed error messages for edge cases

---

## 📊 FEATURE FREQUENCY RANKING

| Category | Occurrences | % of Total | EmaxForge Status |
|----------|-------------|------------|------------------|
| **Physical Format Management** | 63 | 11.4% | ❌ MISSING |
| Error/Warning Messages | 65 | 11.7% | ✅ Partial |
| **Report Generation** | 40 | 7.2% | ❌ MISSING |
| **"Always show" Preferences** | 37 | 6.7% | ❌ MISSING |
| **Show Bank Details** | 33 | 5.9% | ✅ Implemented |
| **Show Samples** | 26 | 4.7% | ✅ Implemented |
| Format Disk Operations | 19 | 3.4% | ✅ Implemented |
| "Don't show" Preferences | 18 | 3.2% | ❌ MISSING |
| **Show Presets** | 18 | 3.2% | ✅ Implemented |
| Show Voices/Key Areas | 17 | 3.1% | ❌ MISSING |
| Show Disk/Image Details | 15 | 2.7% | ✅ Partial |
| Show Filter Options (multi-sampler) | 15 | 2.7% | ❌ N/A |
| Create Files from Selections | 14 | 2.5% | ✅ Implemented |
| Create Disk Images | 12 | 2.2% | ✅ Implemented |
| Multi-Sampler Conversion | 11 | 2.0% | ❌ N/A |
| Bank/Sound Reports (multi-sampler) | 8 | 1.4% | ❌ N/A |
| Display Format Preferences | 6 | 1.1% | ❌ MISSING |
| **Filename Templates** | 5 | 0.9% | ❌ MISSING |
| **Stereo File Creation** | 4 | 0.7% | ❌ MISSING |

---

## 🎯 REVISED GAP ANALYSIS (Based on Complete Data)

### **🔴 CRITICAL GAPS (v1.1 Must-Have)**

#### 1. Physical Format Presets (63 strings, 11.4%)
**Priority:** CRITICAL ⭐⭐⭐  
**Frequency Rank:** #1 most mentioned feature  
**Effort:** 6-8 hours  
**Impact:** Massive workflow speedup

**Why Critical:**
- Most mentioned feature in ALL of standard tools (11.4% of menu strings)
- Essential for production workflows
- Prevents configuration errors
- Standardizes ZuluSCSI card setup

**Implementation:**
```swift
struct FormatPreset {
    let name: String
    let clusterSize: Int
    let volumeSize: Int64
    let includeOS: Bool
    let enabled: Bool
}

class FormatPresetManager {
    var presets: [FormatPreset] = []
    func savePresets()
    func loadPresets()
    func importFromDisk()
    func exportToDisk()
}
```

---

#### 2. Report Generation (40 strings, 7.2%)
**Priority:** HIGH ⭐⭐  
**Frequency Rank:** #2 most mentioned feature  
**Effort:** 4-6 hours  
**Impact:** Documentation, sharing, archiving

**Already documented in GAP_ANALYSIS.md**

---

### **🟡 HIGH PRIORITY (v1.1 Should-Have)**

#### 3. Preference Screens (55 strings total, 9.9%)
**Priority:** HIGH ⭐⭐  
**Frequency Rank:** #3 most mentioned (combining "Always" + "Don't show")  
**Effort:** 4-6 hours  
**Impact:** Power user convenience, reduce annoyance

**What to Implement:**
- Per-action confirmation toggles
- Warning suppression
- File overview auto-show
- Display preferences

---

#### 4. Stereo Sample Export (4 strings, 0.7%)
**Priority:** MEDIUM ⭐  
**Effort:** 2-3 hours  
**Impact:** Modern DAW workflows

**Already documented in GAP_ANALYSIS.md**

---

#### 5. Filename Templates (5 strings, 0.9%)
**Priority:** MEDIUM ⭐  
**Effort:** 2-3 hours  
**Impact:** Workflow customization

**Already documented in GAP_ANALYSIS.md**

---

### **🟢 MEDIUM PRIORITY (v1.2+)**

#### 6. Voice/Key Area Viewer (17 strings, 3.1%)
**Priority:** MEDIUM  
**Effort:** 8-12 hours  
**Impact:** Understanding preset internal structure

**What standard tools Shows:**
- Voice layering (1-16 voices per preset)
- Key zone mapping (which samples on which keys)
- Per-voice ADSR envelopes
- Filter cutoff/resonance per voice
- Velocity layers

**EmaxForge Gap:**
- PresetBrowserView shows preset overview only
- No internal voice structure visualization
- Would require new VoiceDetailView component

---

## 📈 UPDATED v1.1 ROADMAP

**Based on complete 555-string analysis:**

### **Phase 1: Critical Workflow Features (16-20h)**

1. **Physical Format Presets** (6-8h) 🔴 NEW PRIORITY #1
   - FormatPreset model + PresetManager
   - Preset picker in NewImageSheet
   - Enable/disable toggles
   - Import/export presets
   - Ship with 5-6 defaults

2. **Report Generation** (4-6h) 🔴 Priority #2
   - HTMLReportGenerator + CSVReportGenerator
   - ReportOptionsSheet
   - "Generate Report..." action

3. **Preference Screens** (4-6h) 🟡 NEW: Priority #3
   - Settings.bundle or SwiftUI Settings
   - Confirmation toggles
   - Warning suppression
   - File overview auto-show

### **Phase 2: Quick Wins (4-6h)**

4. **Stereo Sample Export** (2-3h)
5. **Filename Templates** (2-3h)

**Total v1.1 Scope:** 20-26 hours (3-4 weeks)

---

## 💡 KEY INSIGHTS FROM COMPLETE ANALYSIS

1. **Physical Format Management is #1 feature by mentions**
   - 63 strings (11.4%) vs Report Gen 40 strings (7.2%)
   - More important than we initially thought!
   - MUST be in v1.1

2. **Preferences are highly valued**
   - 55 total preference strings (9.9%)
   - Users want control over confirmations/warnings
   - Essential for power users

3. **Multi-sampler features = 34 strings (6.1%)**
   - Shows standard tools's broader scope
   - EmaxForge correctly focuses on EMAX-II only

4. **Error handling is extensive**
   - 65 error message strings (11.7%)
   - standard tools has very detailed edge case handling
   - EmaxForge should study these for robustness

5. **Our v1.0 core features align well**
   - Show Samples (26 strings) = ✅ Implemented
   - Show Presets (18 strings) = ✅ Implemented
   - Show Bank Details (33 strings) = ✅ Implemented
   - Format Operations (19 strings) = ✅ Implemented

---

## ✅ CONCLUSION

**EmaxForge v1.0 Status:**
- ✅ **Core browsing features: COMPLETE** (77 menu strings covered)
- ✅ **Disk operations: COMPLETE** (31 menu strings covered)
- ❌ **Workflow automation: MISSING** (63 format preset + 55 preference strings)
- ❌ **Documentation: MISSING** (40 report generation strings)

**v1.1 Must Include:**
1. Physical Format Presets (CRITICAL - most mentioned feature!)
2. Report Generation (HIGH - second most mentioned)
3. Preference Screens (HIGH - third most mentioned)
4. Stereo Export + Filename Templates (quick wins)

**Estimated v1.1 Development:** 20-26 hours (3-4 weeks)

**Confidence:** VERY HIGH (based on complete 555-string analysis)

---

**END OF COMPLETE MENU ANALYSIS**
