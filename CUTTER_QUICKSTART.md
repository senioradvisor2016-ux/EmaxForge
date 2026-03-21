# Cutter Quick Start - standard tools Analysis

## Getting Started

**Cutter is now open with standardn.exe loaded!**

### First-Time Setup (in Cutter)
1. **Wait for analysis** - Cutter is analyzing the PE32 file (may take 30-60 seconds)
2. **Check Analysis Progress** - Look for progress bar at bottom
3. **When done** - You'll see function list, disassembly, etc.

## Key Areas in Cutter UI

```
┌─────────────────────────────────────────┐
│  Functions  │  Main View  │  Hexdump    │
│             │             │             │
│  - main     │  Assembly   │  00 11 22   │
│  - func1    │  Decompile  │  33 44 55   │
│  - func2    │  Graph      │  66 77 88   │
│             │             │             │
└─────────────────────────────────────────┘
```

## Step 1: Find Interesting Functions

### Search by String References
**Goal:** Find "Create Boot Disk" code by searching for UI strings

1. **Click:** Windows → Strings (or Cmd+Shift+S)
2. **Search for:**
   - "boot" (boot disk creation)
   - "format" (disk formatting)
   - "EMX2" (EMAX II signature)
   - "0x7882" (boot signature we found)
   
3. **Right-click string → Find References**
   - Shows which functions use this string
   - These are likely the UI handlers!

### Search by Import/Export
**Goal:** Find Windows API calls (WriteFile, SetFilePointer, etc.)

1. **Click:** Windows → Imports
2. **Look for:**
   - `kernel32.dll!WriteFile` - Disk write operations
   - `kernel32.dll!SetFilePointer` - Seek to offset
   - `kernel32.dll!CreateFileA` - Open .EZ2 files
   
3. **Right-click import → Find References**
   - Shows ALL places standard tools writes to files
   - Filter to boot disk creation functions

## Step 2: Analyze a Function

### Example: Find Boot Signature Writer

**In Strings window, search:** "7882" or look for hex `78 82`

1. **Double-click function** in references
2. **Switch to Decompiler view** (top tabs)
3. **Read the pseudocode:**

```c
// Example decompiled output (not real standard tools code)
void writeBootSignature(HANDLE hFile) {
    unsigned char signature[2] = {0x78, 0x82};
    DWORD bytesWritten;
    SetFilePointer(hFile, 0x1FE, NULL, FILE_BEGIN);
    WriteFile(hFile, signature, 2, &bytesWritten, NULL);
}
```

4. **Compare with EmaxForge:**
```swift
// ImageCreator.swift line 193
header.writeU16LE(0x8278, at: 0x1FE)  // Boot signature
```

**If they match:** ✅ EmaxForge is correct!
**If different:** Note what standard tools does differently

## Step 3: Export Pseudocode

### Save Decompilation for Later

1. **Right-click in decompiler window**
2. **Copy to clipboard** or **Export to file**
3. **Save as:** `~/clawd/EmaxForge/cutter-analysis/function_NAME.c`

## Step 4: Graph View (Advanced)

### Visual Flow Analysis

1. **Click:** Graph tab (top)
2. **See:** Visual flowchart of function logic
3. **Navigate:** Scroll/zoom to explore branches

**Useful for:**
- Understanding complex conditionals
- Finding error handling paths
- Spotting validation checks

## Common Tasks for standard tools

### Task 1: How does standard tools write the FAT?
```
1. Search strings: "FAT" or "file allocation"
2. OR: Search imports: WriteFile references
3. Filter to offset 0x400 (FAT location we know)
4. Decompile function
5. Document algorithm
```

### Task 2: How does standard tools validate boot disks?
```
1. Search strings: "invalid" or "corrupt" or "error"
2. Find validation function
3. Look for comparisons:
   - if (signature != 0x7882) → error
   - if (clusterSize != 0x8200) → error
4. Document all checks
```

### Task 3: How does standard tools import WAV files?
```
1. Search strings: ".wav" or "wave" or "pcm"
2. Find import function
3. Look for:
   - Sample rate conversion
   - Bit depth conversion (16-bit → 13-bit EMAX II)
   - Stereo → mono conversion
4. Implement in Swift
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| **g** | Go to address/function |
| **x** | Find cross-references (where is this used?) |
| **/** | Add comment |
| **;** | Add comment (alternative) |
| **Space** | Toggle between disassembly/graph/decompile |
| **Tab** | Switch between panels |
| **Cmd+F** | Search in current view |

## Workflow Example: Reverse Engineer "Format Disk"

### Step-by-Step

1. **Find function:**
   ```
   Strings → Search "format"
   → Right-click "Format Disk" string
   → Find References
   → Double-click function (e.g., sub_401234)
   ```

2. **Analyze:**
   ```
   Switch to Decompiler tab
   Read pseudocode
   Look for:
   - File I/O (WriteFile calls)
   - Magic numbers (0x454D4158 = "EMAX")
   - Structure initialization
   ```

3. **Document:**
   ```c
   // standard tools Format Disk Algorithm (from Cutter decompilation)
   void formatDisk(char* filepath, int sizeMB) {
       // 1. Create file
       HANDLE hFile = CreateFile(filepath, ...);
       
       // 2. Write header (512 bytes)
       writeHeader(hFile, sizeMB);
       
       // 3. Write FAT (at offset 0x400)
       writeFAT(hFile, sizeMB);
       
       // 4. Write catalog (at offset 0x1000)
       writeCatalog(hFile);
       
       // 5. Pad with zeros
       padToSize(hFile, sizeMB * 1024 * 1024);
   }
   ```

4. **Implement in Swift:**
   ```swift
   // EmaxForge/ImageCreator.swift
   static func formatDisk(at url: URL, sizeMB: Int) throws {
       // Match standard tools algorithm exactly
       let header = createHeader(sizeMB: sizeMB)
       let fat = createFAT(sizeMB: sizeMB)
       let catalog = createCatalog()
       // ... etc
   }
   ```

5. **Verify:**
   ```bash
   # Create disk in standard tools
   # Create disk in EmaxForge
   # Binary compare
   diff <(xxd emax2_disk.ez2) <(xxd emaxforge_disk.hda)
   ```

## Tips for Success

### Rename Functions
When you find what a function does:
1. **Right-click function name**
2. **Rename** (e.g., `sub_401234` → `writeBootSignature`)
3. **Saves time later!**

### Add Comments
Document as you go:
1. **Press `/` or `;`**
2. **Type comment** (e.g., "This writes FAT entry 0")
3. **Comments persist** in Cutter project

### Save Project
Don't lose your work:
1. **File → Save Project**
2. **Save as:** `~/clawd/EmaxForge/cutter-analysis/standard.rzdb`
3. **Next time:** Open project instead of raw .exe

## Next Steps

**After exploring Cutter for 1-2 hours:**

1. **Document findings** in `CUTTER_FINDINGS.md`
2. **Compare with Binary Ninja trial** (download Monday)
3. **Decide:** Cutter (free) or Binary Ninja ($149)?

**First target:** Find and document "Format Disk" algorithm

---

**Ready to start?** Open Cutter and search for "boot" or "format" in Strings window!
