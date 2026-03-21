import SwiftUI

/// Built-in reference guide for EMAX II and ZuluSCSI
struct KnowledgeBaseView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedArticle: Article?
    @State private var searchText = ""
    
    var filteredArticles: [Article] {
        if searchText.isEmpty { return Article.allArticles }
        return Article.allArticles.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Knowledge Base",
                subtitle: "EMAX II & ZuluSCSI reference",
                icon: "book",
                onClose: { dismiss() }
            )
            
            Divider()
            
            NavigationSplitView {
                VStack(spacing: 0) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.tertiary)
                        TextField("Search…", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    .padding(8)
                    
                    List(filteredArticles, selection: $selectedArticle) { article in
                        HStack(spacing: 10) {
                            Image(systemName: article.icon)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(article.title)
                                    .fontWeight(.medium)
                                Text(article.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(article)
                    }
                }
            } detail: {
                if let article = selectedArticle {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 10) {
                                Image(systemName: article.icon)
                                    .font(.title2)
                                    .foregroundStyle(Theme.accent)
                                Text(article.title)
                                    .font(.title.bold())
                            }
                            
                            Divider()
                            
                            Text(article.content)
                                .textSelection(.enabled)
                                .lineSpacing(3)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "book")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("Select an article")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(minWidth: 900, idealWidth: 1000, minHeight: 700, idealHeight: 750)
        .onExitCommand { dismiss() }
    }
}

struct Article: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let content: String
    
    static let allArticles: [Article] = [
        Article(
            title: "Boot Requirements",
            subtitle: "How EMAX II boots from SCSI",
            icon: "power",
            content: """
            EMAX II Boot Process
            
            The EMAX II ALWAYS boots from SCSI ID 1 (HD1).
            This is hardcoded in the hardware — it cannot be changed.
            
            Requirements for a bootable disk:
            1. File must be named HD10.hda (or HD10_0.hda for multi-image)
            2. The disk image must contain the EMAX II OS (.EMX)
            3. The OS is loaded into RAM at startup (~16-32 KB)
            
            Recommended OS: v2.14 (latest and most stable)
            
            Common mistake:
            Having only HD00.hda on the SD card without HD10.
            → The EMAX II will NOT boot because there is no disk at SCSI ID 1.
            
            Correct setup:
            • HD10.hda — Boot disk with OS (SCSI ID 1) ✅
            • HD20.hda — Data/sample disk (SCSI ID 2, optional)
            
            The boot disk can also contain banks and samples — it doesn't need to be OS-only. Use the Bootable Disk Wizard (⇧⌘B) to create a properly configured HD10.
            
            Without HD10:
            The sampler will show no response or display an error. It has no OS to run and cannot access any other SCSI devices until the OS is loaded.
            """
        ),
        Article(
            title: "File Formats",
            subtitle: "EZ2, EB2, EMX, HDA explained",
            icon: "doc",
            content: """
            EMAX II File Formats
            
            .EZ2 — EMAX II HD image
            Full disk image containing banks, presets, and samples.
            
            .EB2 — EMAX II Bank file
            Native bank format. Contains presets and associated samples.
            
            .EMX — EMAX II OS file
            Operating system image for the EMAX II.
            
            .hda — Raw HD image for ZuluSCSI
            Standard hard drive image format used by ZuluSCSI.
            
            Important!
            
            .EZ2 and .hda are IDENTICAL formats!
            Simply rename the file — no conversion needed.
            
            ⚠️ DO NOT use `dd skip=1` — this is a common myth that CORRUPTS the image by stripping valid data.
            """
        ),
        Article(
            title: "ZuluSCSI Naming",
            subtitle: "How to name files for ZuluSCSI",
            icon: "sdcard",
            content: """
            ZuluSCSI File Naming Convention
            
            ZuluSCSI uses the filename to determine SCSI configuration:
            
            Basic: HDx.hda
            • x = SCSI ID (0-6)
            • Example: HD1.hda → SCSI ID 1
            
            Multi-image: HDx_y_label.hda
            • x = SCSI ID
            • y = Image index (0, 1, 2…)
            • label = Optional description (ignored by ZuluSCSI)
            • Example: HD1_0_strings.hda → SCSI ID 1, first image
            
            Switching images:
            Press the button on ZuluSCSI Pico to cycle through images for a given SCSI ID. LED blinks indicate current image number.
            
            Other prefixes:
            • CD = CD-ROM (CDx.iso)
            • FD = Floppy (FDx.img)
            
            SCSI ID 7 is reserved for the host controller — don't use it!
            """
        ),
        Article(
            title: "SCSI Termination",
            subtitle: "Getting the chain right",
            icon: "link",
            content: """
            SCSI Termination
            
            SCSI requires proper termination at both ends of the chain.
            
            Rules:
            1. The host (EMAX II) provides termination at one end
            2. The last device on the chain must be terminated
            3. Middle devices should NOT be terminated
            
            ZuluSCSI Pico:
            • Has a termination jumper/setting
            • Enable it if ZuluSCSI is the only/last device
            • Disable it if there are other SCSI devices after it
            
            Common setup (EMAX II + ZuluSCSI only):
            EMAX II (terminated) ←→ ZuluSCSI (terminated)
            ✅ Both ends terminated — correct!
            
            With Gotek too:
            EMAX II (terminated) ←→ Gotek (NOT terminated) ←→ ZuluSCSI (terminated)
            ✅ Only ends terminated — correct!
            
            Symptoms of bad termination:
            • Drive not detected
            • Random errors / data corruption
            • Intermittent connection
            """
        ),
        Article(
            title: "SD Card Tips",
            subtitle: "Choosing and formatting SD cards",
            icon: "internaldrive",
            content: """
            SD Card Requirements
            
            Format: FAT32 (mandatory)
            Max size: 32 GB recommended for best compatibility
            Speed: Class 10 / UHS-I minimum
            
            Formatting on macOS:
            1. Open Disk Utility
            2. Select the SD card
            3. Click "Erase"
            4. Format: MS-DOS (FAT32)
            5. Scheme: Master Boot Record
            
            Or via Terminal:
            diskutil eraseDisk FAT32 ZULUSCI MBRFormat /dev/diskN
            (Replace diskN with your actual disk number)
            
            Tips:
            • Use a quality brand (SanDisk, Samsung)
            • Don't use exFAT — ZuluSCSI needs FAT32
            • Cards >32 GB may need special formatting tools
            • Always "Eject" before removing the card
            """
        ),
        Article(
            title: "Troubleshooting",
            subtitle: "Common issues and fixes",
            icon: "wrench",
            content: """
            Common Issues
            
            EMAX II doesn't see the drive:
            1. Check SCSI cable (50-pin) is properly seated
            2. Verify termination (see Termination article)
            3. Check SCSI ID isn't conflicting with another device
            4. Try increasing SelectionDelay in zuluscsi.ini
            5. Try a different SD card
            
            "Disk Error" when loading:
            • Image may be corrupted
            • Check image size is block-aligned (multiple of 512 bytes)
            • Try a known-good image
            • Was `dd skip=1` used? This corrupts EMAX II images!
            
            ZuluSCSI LED patterns:
            • Solid: Ready
            • Blinking: Activity
            • Fast blink on boot: Error (check SD card)
            
            Image switching doesn't work:
            • Ensure files follow HDx_y naming convention
            • Button press cycles through images for active SCSI ID
            • LED blink count = current image number
            
            EMAX II boots slowly:
            • Normal — SCSI enumeration takes a few seconds
            • Reduce StartupDelay in zuluscsi.ini if too slow
            """
        ),
    ]
}
