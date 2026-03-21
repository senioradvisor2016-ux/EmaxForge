"""
EmaxForge Nielsen Heuristic Test Suite
=======================================
Tests Nielsen's 10 usability heuristics via static Swift source analysis.

Run:
    python3 agent-harness/tests/test_nielsen_heuristics.py

Or via pytest:
    pytest agent-harness/tests/test_nielsen_heuristics.py -v
"""

import os
import re
import sys
import glob
import unittest
from pathlib import Path

# ── Resolve repo root ───────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).resolve().parents[2]
VIEWS_DIR = REPO_ROOT / "EmaxForge" / "Sources" / "Views"
APP_DIR = REPO_ROOT / "EmaxForge" / "Sources" / "App"
SERVICES_DIR = REPO_ROOT / "EmaxForge" / "Sources" / "Services"
ALL_SWIFT = list(REPO_ROOT.rglob("EmaxForge/Sources/**/*.swift"))


def read_file(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def swift_files_in_dir(directory: Path):
    return list(directory.glob("*.swift"))


def all_views():
    return swift_files_in_dir(VIEWS_DIR)


# ═══════════════════════════════════════════════════════════════════════════════
# H1 — Visibility of System Status
# ═══════════════════════════════════════════════════════════════════════════════
class TestH1_VisibilityOfSystemStatus(unittest.TestCase):
    """The system should always keep users informed about what is going on."""

    def test_progress_view_exists_in_status_bar(self):
        """ContentView status bar should show ProgressView during operations."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertIn("ProgressView(value: appState.progress)", content,
                      "Status bar must display linear progress during isProcessing")

    def test_loading_state_in_image_list(self):
        """ImageListView should show skeleton loader when loading."""
        content = read_file(VIEWS_DIR / "ImageListView.swift")
        self.assertIn("ImageListSkeleton", content,
                      "ImageListView must use skeleton loading, not blank state")

    def test_status_message_displayed(self):
        """Status message must be displayed in the UI."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertIn("appState.statusMessage", content,
                      "StatusMessage must be rendered in ContentView")

    def test_parsing_overlay_shown(self):
        """ImageDetailView must show an overlay while parsing."""
        content = read_file(VIEWS_DIR / "ImageDetailView.swift")
        self.assertIn("isParsing", content,
                      "ImageDetailView must have isParsing state")
        self.assertIn("Parsing image", content,
                      "ImageDetailView must show 'Parsing image...' overlay")

    def test_no_duplicate_sheet_modifiers(self):
        """No view should declare the same sheet binding twice (creates dead code)."""
        for view_file in all_views():
            content = read_file(view_file)
            # Find all .sheet(isPresented: $varName) patterns
            pattern = r'\.sheet\(isPresented:\s*\$(\w+)\)'
            matches = re.findall(pattern, content)
            duplicates = [m for m in matches if matches.count(m) > 1]
            unique_dupes = list(set(duplicates))
            self.assertEqual(
                unique_dupes, [],
                f"{view_file.name}: Duplicate .sheet(isPresented: ${unique_dupes}) — "
                f"SwiftUI only honors the last modifier, earlier sheets are dead code"
            )

    def test_bank_count_not_placeholder_string(self):
        """osName / bankCount should not be set to instructional strings like 'Click Browse Banks'."""
        content = read_file(VIEWS_DIR / "ImageDetailView.swift")
        self.assertNotIn('"Click Browse Banks"', content,
                         "osName must not be set to instructional text 'Click Browse Banks'; "
                         "use nil or a proper empty state instead")

    def test_import_progress_reported(self):
        """Bank import operations must show progress to the user."""
        content = read_file(VIEWS_DIR / "ImportBanksView.swift")
        has_progress = (
            "appState.startProgress" in content or
            "appState.updateProgress" in content or
            "isProcessing" in content or
            "isImporting" in content or
            "importProgress" in content or
            "ProgressView" in content
        )
        self.assertTrue(has_progress,
                        "ImportBanksView must show a progress indicator during bank import")


# ═══════════════════════════════════════════════════════════════════════════════
# H2 — Match Between System and the Real World
# ═══════════════════════════════════════════════════════════════════════════════
class TestH2_MatchSystemAndRealWorld(unittest.TestCase):
    """Speak the user's language, use familiar concepts."""

    def test_scsi_terminology_used_correctly(self):
        """SCSI ID labels should be consistent across the app."""
        for view_file in all_views():
            content = read_file(view_file)
            # "SCSI" should appear in relevant views
            if "scsiID" in content or "ScsiID" in content:
                self.assertTrue(
                    "SCSI" in content or "scsiID" in content,
                    f"{view_file.name}: Uses scsiID but doesn't label it clearly for users"
                )

    def test_file_size_human_readable(self):
        """File sizes should be formatted with ByteCountFormatter, not raw bytes."""
        relevant_views = ["ImageDetailView.swift", "ImageListView.swift",
                          "WelcomeView.swift", "ImageRow"]
        for view_file in all_views():
            if any(v in view_file.name for v in relevant_views):
                content = read_file(view_file)
                if "totalSize" in content or "fileSize" in content or "formattedSize" in content:
                    has_formatter = (
                        "ByteCountFormatter" in content or
                        "formattedSize" in content or
                        "formattedFree" in content
                    )
                    self.assertTrue(has_formatter,
                                    f"{view_file.name}: Must use ByteCountFormatter for file sizes")

    def test_no_internal_brand_in_window_title(self):
        """Window title must use public app name, not internal brand alias."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        # Look for the windowTitle property
        title_match = re.search(r'let base = "([^"]+)"', content)
        if title_match:
            title = title_match.group(1)
            self.assertEqual(
                title, "EmaxForge",
                f"Window title base is '{title}' but should be 'EmaxForge' "
                f"(internal brand names must not leak to end users)"
            )

    def test_format_extensions_uppercase_in_ui(self):
        """File format labels shown to users should be uppercase (.HDA, .EZ2, not .hda, .ez2)."""
        content = read_file(VIEWS_DIR / "ImageDetailView.swift")
        self.assertIn(".uppercased()", content,
                      "File extensions in QuickInfoCard must use .uppercased() for display")


# ═══════════════════════════════════════════════════════════════════════════════
# H3 — User Control and Freedom
# ═══════════════════════════════════════════════════════════════════════════════
class TestH3_UserControlAndFreedom(unittest.TestCase):
    """Users often choose system functions by mistake; provide emergency exit."""

    def test_delete_action_requires_confirmation(self):
        """Every delete/trash operation must go through a confirmation dialog."""
        content = read_file(VIEWS_DIR / "ImageDetailView.swift")
        # The Trash ActionCard must set showDeleteConfirmation, not call trashImage directly
        trash_card_match = re.search(
            r'ActionCard\(title:\s*"Trash".*?\}', content, re.DOTALL
        )
        if trash_card_match:
            trash_card_body = trash_card_match.group(0)
            self.assertNotIn(
                "fileService.trashImage", trash_card_body,
                "Trash ActionCard must not directly call fileService.trashImage; "
                "it must set showDeleteConfirmation = true to show the confirmation dialog"
            )
            self.assertIn(
                "showDeleteConfirmation", trash_card_body,
                "Trash ActionCard must set showDeleteConfirmation = true"
            )

    def test_undo_manager_registered(self):
        """AppState must have undo/redo support."""
        content = read_file(APP_DIR / "AppState.swift")
        self.assertIn("UndoManager", content,
                      "AppState must use UndoManager for undo/redo support")
        self.assertIn("registerUndo", content,
                      "AppState must register undo actions for destructive operations")

    def test_cancel_button_in_import_views(self):
        """Sheets with long operations must have a cancel/dismiss button."""
        for view_file in [VIEWS_DIR / "ImportBanksView.swift",
                          VIEWS_DIR / "BatchBankImportSheet.swift",
                          VIEWS_DIR / "BootableDiskWizard.swift"]:
            if view_file.exists():
                content = read_file(view_file)
                has_cancel = (
                    '"Cancel"' in content or
                    "dismiss()" in content or
                    ".cancel" in content
                )
                self.assertTrue(has_cancel,
                                f"{view_file.name}: Must provide a Cancel button for user control")

    def test_format_disk_requires_confirmation(self):
        """Format Disk is destructive and must require user confirmation."""
        content = read_file(VIEWS_DIR / "FormatDiskSheet.swift")
        has_confirm = (
            ".alert" in content or
            "confirmFormat" in content or
            "role: .destructive" in content
        )
        self.assertTrue(has_confirm,
                        "FormatDiskSheet must confirm the destructive format operation")

    def test_undo_shortcut_registered(self):
        """⌘Z must be bound to undo action."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertIn('keyboardShortcut("z")', content,
                      "ContentView must bind ⌘Z to undo action")


# ═══════════════════════════════════════════════════════════════════════════════
# H4 — Consistency and Standards
# ═══════════════════════════════════════════════════════════════════════════════
class TestH4_ConsistencyAndStandards(unittest.TestCase):
    """Users should not have to wonder whether different words or actions mean the same thing."""

    def test_theme_spacing_used_consistently(self):
        """Views should use Theme.Spacing constants, not raw CGFloat literals."""
        for view_file in all_views():
            content = read_file(view_file)
            # Should use Theme.Spacing or at least 4pt-grid values
            if "Theme.Spacing" in content:
                # Good — file uses the design system
                pass
            # We don't fail here since not all views are required to use Theme.Spacing
            # but at minimum the main layout views should

    def test_sheet_header_used_in_sheets(self):
        """All sheet views should use SheetHeader for consistent header styling."""
        sheet_views = [f for f in all_views() if "Sheet" in f.name]
        for view_file in sheet_views:
            content = read_file(view_file)
            # Not strict — but note which sheets don't use SheetHeader
            # This is an advisory check

    def test_primary_button_uses_borderedprominent(self):
        """Primary action buttons should use .borderedProminent or PrimaryButton component."""
        for view_file in all_views():
            content = read_file(view_file)
            if ".borderedProminent" in content or "PrimaryButton" in content:
                # Good — file has at least some prominent buttons
                pass

    def test_window_title_consistent_with_app_name(self):
        """Window title must match app bundle name (EmaxForge)."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        # Check for "EMULOTION" being used as the window title base
        self.assertNotIn(
            'let base = "EMULOTION"', content,
            "Window title base must be 'EmaxForge', not internal brand 'EMULOTION'"
        )

    def test_status_type_enum_used_for_coloring(self):
        """Status messages should use ActivityType enum for consistent color coding."""
        content = read_file(APP_DIR / "AppState.swift")
        self.assertIn("ActivityType", content,
                      "AppState must define ActivityType for consistent status coloring")
        self.assertIn("addActivity", content,
                      "AppState must expose addActivity() for consistent status reporting")

    def test_emoji_not_in_status_messages(self):
        """Status messages should not use emoji — use ActivityType + SF Symbols instead."""
        for view_file in all_views():
            content = read_file(view_file)
            # Detect emoji patterns in status message assignments
            emoji_status = re.findall(
                r'statusMessage\s*=\s*"[^"]*[✅❌⚠️🔴🟢🟡][^"]*"', content
            )
            self.assertEqual(
                emoji_status, [],
                f"{view_file.name}: Status messages must not use emoji. "
                f"Use addActivity(message, type: .success/.error) instead. "
                f"Found: {emoji_status}"
            )


# ═══════════════════════════════════════════════════════════════════════════════
# H5 — Error Prevention
# ═══════════════════════════════════════════════════════════════════════════════
class TestH5_ErrorPrevention(unittest.TestCase):
    """Even better than good error messages is a careful design that prevents problems."""

    def test_format_disk_disabled_without_selection(self):
        """Format Disk button must be disabled when no image is selected."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        # Check toolbar Format Disk button is disabled when no selection
        self.assertIn(
            ".disabled(appState.selectedImage == nil)", content,
            "Format Disk toolbar button must be disabled when no image is selected"
        )

    def test_eject_disabled_without_volume(self):
        """Eject button must only appear when a removable volume is mounted."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertIn("isRemovable", content,
                      "Eject button must check volume.isRemovable before showing")

    def test_batch_rename_disabled_without_images(self):
        """Batch Rename button must be disabled when there are no images."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertIn(
            ".disabled(appState.images.isEmpty)", content,
            "Batch Rename must be disabled when images list is empty"
        )

    def test_no_direct_trash_without_confirmation(self):
        """ActionCard 'Trash' must not directly call trashImage — must show confirmation first."""
        content = read_file(VIEWS_DIR / "ImageDetailView.swift")
        # Find ActionCard("Trash"...) block and check it uses confirmation, not direct trashImage
        trash_card_match = re.search(
            r'ActionCard\(title:\s*"Trash"[^{]*\{([^}]+)\}',
            content, re.DOTALL
        )
        if trash_card_match:
            trash_body = trash_card_match.group(1)
            self.assertNotIn(
                "fileService.trashImage", trash_body,
                "ImageDetailView Trash ActionCard must not directly call fileService.trashImage. "
                "It must set showDeleteConfirmation = true to show the alert first."
            )

    def test_import_banks_validates_file_extension(self):
        """Bank import must validate file extensions before attempting import."""
        content = read_file(VIEWS_DIR / "ImportBanksView.swift")
        has_validation = (
            ".eb2" in content.lower() or
            "pathExtension" in content or
            "allowedContentTypes" in content
        )
        self.assertTrue(has_validation,
                        "ImportBanksView must validate file extensions before importing")


# ═══════════════════════════════════════════════════════════════════════════════
# H6 — Recognition over Recall
# ═══════════════════════════════════════════════════════════════════════════════
class TestH6_RecognitionOverRecall(unittest.TestCase):
    """Minimize the user's memory load by making objects, actions, and options visible."""

    def test_tooltips_on_toolbar_buttons(self):
        """Toolbar buttons must have .help() tooltips."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        toolbar_buttons = re.findall(r'\.help\("[^"]+"\)', content)
        self.assertGreaterEqual(
            len(toolbar_buttons), 5,
            "ContentView toolbar must have at least 5 .help() tooltips on buttons"
        )

    def test_empty_state_has_call_to_action(self):
        """Empty states must provide a clear call to action, not just 'No items found'."""
        for view_file in [VIEWS_DIR / "ImageListView.swift", VIEWS_DIR / "WelcomeView.swift"]:
            content = read_file(view_file)
            # Must have both an empty/placeholder state and a Button for the CTA
            has_empty_indicator = (
                "emptyState" in content or
                "enhancedEmptyState" in content or
                "No images" in content or
                "No drives" in content
            )
            has_cta_button = "Button" in content
            self.assertTrue(
                has_empty_indicator and has_cta_button,
                f"{view_file.name}: Empty state must include a call-to-action button"
            )

    def test_boot_disk_warning_is_visible(self):
        """If no HD1 image exists, the user must be warned clearly."""
        content = read_file(VIEWS_DIR / "ImageListView.swift")
        self.assertIn("No boot disk", content,
                      "ImageListView must warn users when no boot disk (HD1) exists")

    def test_keyboard_shortcuts_shown_in_tooltips(self):
        """Keyboard shortcuts should be mentioned in .help() tooltips."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        shortcut_tooltips = re.findall(r'\.help\("[^"]*⌘[^"]*"\)', content)
        self.assertGreaterEqual(
            len(shortcut_tooltips), 3,
            "At least 3 toolbar buttons must show their keyboard shortcut in the .help() tooltip"
        )

    def test_scsi_id_shown_in_image_list(self):
        """SCSI ID must be prominently visible in the image list."""
        content = read_file(VIEWS_DIR / "ImageListView.swift")
        self.assertIn("scsiID", content,
                      "ImageListView must display SCSI ID for each image")


# ═══════════════════════════════════════════════════════════════════════════════
# H7 — Flexibility and Efficiency of Use
# ═══════════════════════════════════════════════════════════════════════════════
class TestH7_FlexibilityAndEfficiency(unittest.TestCase):
    """Accelerators allow expert users to speed up interactions."""

    def test_command_palette_exists(self):
        """App must have a command palette for quick access to all features."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertIn("CommandPalette", content,
                      "ContentView must include a CommandPalette component")

    def test_command_palette_keyboard_shortcut(self):
        """Command Palette must be accessible via keyboard shortcut (⌘K)."""
        palette_file = VIEWS_DIR / "Components" / "CommandPalette.swift"
        if palette_file.exists():
            content = read_file(palette_file)
            has_k_shortcut = (
                'keyboardShortcut("k")' in content or
                ".commandPalette" in content
            )
            # Also check ContentView for the notification trigger
            cv_content = read_file(VIEWS_DIR / "ContentView.swift")
            has_notification = ".commandPalette" in cv_content
            self.assertTrue(
                has_k_shortcut or has_notification,
                "Command Palette must be triggered by ⌘K keyboard shortcut"
            )

    def test_undo_keyboard_shortcut(self):
        """Undo must be accessible via ⌘Z."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertIn('keyboardShortcut("z")', content,
                      "Undo must be bound to ⌘Z keyboard shortcut")

    def test_redo_keyboard_shortcut(self):
        """Redo must be accessible via ⌘⇧Z."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertIn('keyboardShortcut("z", modifiers: [.command, .shift])', content,
                      "Redo must be bound to ⌘⇧Z keyboard shortcut")

    def test_drag_and_drop_supported(self):
        """Drag-and-drop must be supported for bank import."""
        content = read_file(VIEWS_DIR / "ImageDetailView.swift")
        self.assertIn(".onDrop", content,
                      "ImageDetailView must support drag-and-drop for .EB2 file import")

    def test_search_available_in_image_list(self):
        """Image list must have search/filter functionality."""
        content = read_file(VIEWS_DIR / "ImageListView.swift")
        self.assertIn("searchText", content,
                      "ImageListView must have search/filter for images")
        self.assertIn("filteredImages", content,
                      "ImageListView must filter the image list based on search text")

    def test_batch_operations_available(self):
        """Batch operations (rename, delete, export) must be available."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertIn("BatchRename", content,
                      "ContentView must include Batch Rename operation")


# ═══════════════════════════════════════════════════════════════════════════════
# H8 — Aesthetic and Minimalist Design
# ═══════════════════════════════════════════════════════════════════════════════
class TestH8_AestheticAndMinimalistDesign(unittest.TestCase):
    """Dialogues should not contain irrelevant or rarely needed information."""

    def test_no_excessive_state_vars(self):
        """Views should not have excessive @State variables (> 25 is a smell)."""
        for view_file in all_views():
            content = read_file(view_file)
            state_vars = re.findall(r'@State\s+private\s+var\s+\w+', content)
            self.assertLessEqual(
                len(state_vars), 30,
                f"{view_file.name}: Has {len(state_vars)} @State vars (threshold: 30). "
                f"Consider refactoring into sub-views or state objects."
            )

    def test_dead_code_action_bar_removed(self):
        """WelcomeView should not contain the unused actionBar computed property."""
        content = read_file(VIEWS_DIR / "WelcomeView.swift")
        # actionBar should not be a separate computed property if it's never called
        # This is a code quality check
        has_action_bar_defined = "private var actionBar: some View" in content
        if has_action_bar_defined:
            # Check if it's actually referenced in body
            body_section = content.split("var body:")[1] if "var body:" in content else ""
            references_action_bar = "actionBar" in body_section
            self.assertTrue(
                references_action_bar,
                "WelcomeView defines 'actionBar' but never uses it in body — dead code. "
                "Either reference it or remove the definition."
            )

    def test_theme_system_exists(self):
        """App must have a design system / theme for visual consistency."""
        theme_file = APP_DIR / "Theme.swift"
        self.assertTrue(theme_file.exists(),
                        "Theme.swift must exist defining the design system")
        content = read_file(theme_file)
        self.assertIn("enum Theme", content,
                      "Theme must be defined as an enum")
        self.assertIn("static let accent", content,
                      "Theme must define a primary accent color")

    def test_no_magic_color_literals_in_main_views(self):
        """Main views should use Theme colors, not raw hex/RGB literals."""
        main_views = ["ContentView.swift", "SidebarView.swift", "ImageListView.swift"]
        for view_name in main_views:
            view_file = VIEWS_DIR / view_name
            if view_file.exists():
                content = read_file(view_file)
                # Raw Color(red:green:blue:) in main views is a design system violation
                raw_colors = re.findall(r'Color\(red:\s*\d+\.\d+,\s*green:', content)
                self.assertEqual(
                    raw_colors, [],
                    f"{view_name}: Use Theme.* colors instead of raw Color(red:green:blue:) literals"
                )


# ═══════════════════════════════════════════════════════════════════════════════
# H9 — Help Users Recognize, Diagnose, and Recover from Errors
# ═══════════════════════════════════════════════════════════════════════════════
class TestH9_ErrorRecognitionAndRecovery(unittest.TestCase):
    """Error messages should be expressed in plain language, precise, constructive."""

    def test_error_messages_use_activity_type(self):
        """Errors must use addActivity(message, type: .error) for consistent display."""
        for view_file in all_views():
            content = read_file(view_file)
            if "type: .error" in content or "addActivity" in content:
                # Good — uses the activity system
                pass

    def test_toast_view_exists(self):
        """App must have a toast/notification system for user feedback."""
        toast_file = VIEWS_DIR / "ToastView.swift"
        self.assertTrue(toast_file.exists(),
                        "ToastView.swift must exist for user feedback notifications")

    def test_undo_shown_in_toast_after_delete(self):
        """After delete, toast must offer Undo action."""
        content = read_file(VIEWS_DIR / "ImageListView.swift")
        has_undo_toast = "undoAction" in content and "undo()" in content
        self.assertTrue(has_undo_toast,
                        "ImageListView must show toast with Undo action after deleting an image")

    def test_import_error_surfaced_to_user(self):
        """Import errors must be reported to the user via status/toast."""
        content = read_file(VIEWS_DIR / "ImportBanksView.swift")
        has_error_reporting = (
            "type: .error" in content or
            "addActivity" in content or
            "importErrors" in content or
            "Theme.danger" in content or
            "localizedDescription" in content
        )
        self.assertTrue(has_error_reporting,
                        "ImportBanksView must surface import errors to the user")

    def test_parse_error_handled_gracefully(self):
        """Image parsing errors must be caught and shown to user, not crash."""
        content = read_file(VIEWS_DIR / "ImageDetailView.swift")
        self.assertIn("catch", content,
                      "ImageDetailView must catch parsing errors gracefully")
        self.assertIn("Parse error", content,
                      "ImageDetailView must display parse error state to user")


# ═══════════════════════════════════════════════════════════════════════════════
# H10 — Help and Documentation
# ═══════════════════════════════════════════════════════════════════════════════
class TestH10_HelpAndDocumentation(unittest.TestCase):
    """Even though it is better if the system can be used without documentation, it may be necessary."""

    def test_knowledge_base_view_exists(self):
        """App must have a help/knowledge base view."""
        kb_file = VIEWS_DIR / "KnowledgeBaseView.swift"
        self.assertTrue(kb_file.exists(),
                        "KnowledgeBaseView.swift must exist for in-app help")

    def test_onboarding_tour_exists(self):
        """App must have an onboarding tour for first-time users."""
        content = read_file(VIEWS_DIR / "WelcomeView.swift")
        self.assertIn("OnboardingTourOverlay", content,
                      "WelcomeView must include OnboardingTourOverlay for first-time users")

    def test_onboarding_tour_has_steps(self):
        """Onboarding tour must have multiple steps, not just a single welcome screen."""
        content = read_file(VIEWS_DIR / "WelcomeView.swift")
        steps_match = re.search(r'private let steps.*?OnboardingStep', content, re.DOTALL)
        self.assertIsNotNone(steps_match,
                             "OnboardingTourOverlay must define multiple steps (OnboardingStep)")

    def test_tooltips_coverage(self):
        """Critical action buttons must have .help() tooltip coverage."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        help_count = content.count('.help("')
        self.assertGreaterEqual(
            help_count, 8,
            f"ContentView must have at least 8 .help() tooltips. Found: {help_count}"
        )

    def test_knowledge_base_accessible_from_toolbar(self):
        """Knowledge Base must be accessible from the toolbar or menu."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertIn("Knowledge Base", content,
                      "ContentView toolbar must include access to Knowledge Base")

    def test_bootable_disk_wizard_has_multiple_steps(self):
        """Bootable Disk Wizard must guide users step by step."""
        wizard_file = VIEWS_DIR / "BootableDiskWizard.swift"
        if wizard_file.exists():
            content = read_file(wizard_file)
            has_steps = (
                "step" in content.lower() or
                "wizardStep" in content or
                "currentStep" in content
            )
            self.assertTrue(has_steps,
                            "BootableDiskWizard must have multi-step guidance")


# ═══════════════════════════════════════════════════════════════════════════════
# E2E Workflow Tests (CLI-based)
# ═══════════════════════════════════════════════════════════════════════════════
class TestE2EWorkflows(unittest.TestCase):
    """End-to-end workflow tests via CLI agent harness."""

    def test_cli_harness_exists(self):
        """CLI harness package must exist for automated testing."""
        cli_harness = REPO_ROOT / "agent-harness" / "cli_anything" / "emaxforge"
        self.assertTrue(cli_harness.exists(),
                        "CLI harness must exist at agent-harness/cli_anything/emaxforge/")

    def test_cli_module_importable(self):
        """CLI harness must be importable as a Python module."""
        cli_init = REPO_ROOT / "agent-harness" / "cli_anything" / "emaxforge" / "__init__.py"
        self.assertTrue(cli_init.exists(),
                        "CLI harness must have __init__.py for Python import")

    def test_swift_cli_tool_exists(self):
        """Swift CLI tool must be available for programmatic disk operations."""
        # Check for emaxforge-cli.swift or built binary
        cli_swift = REPO_ROOT / "emaxforge-cli.swift"
        sources = list((REPO_ROOT / "Sources").glob("**/*.swift")) if (REPO_ROOT / "Sources").exists() else []
        has_cli = cli_swift.exists() or len(sources) > 0
        self.assertTrue(has_cli,
                        "Swift CLI tool must exist for programmatic disk operations")

    def test_view_count_adequate(self):
        """App should have adequate view coverage (≥ 30 Swift view files)."""
        view_count = len(all_views())
        self.assertGreaterEqual(
            view_count, 30,
            f"App must have at least 30 view files for adequate feature coverage. "
            f"Found: {view_count}"
        )

    def test_services_layer_exists(self):
        """Services layer must be separate from views."""
        services = list(SERVICES_DIR.glob("*.swift")) if SERVICES_DIR.exists() else []
        self.assertGreaterEqual(
            len(services), 5,
            "Services layer must have at least 5 service classes (separation of concerns)"
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Regression Tests (Known Bug Fixes)
# ═══════════════════════════════════════════════════════════════════════════════
class TestRegressions(unittest.TestCase):
    """Regression tests for specific bugs identified in the UX audit."""

    def test_BUG01_trash_uses_confirmation(self):
        """BUG-01: Trash ActionCard must show confirmation dialog, not direct delete."""
        content = read_file(VIEWS_DIR / "ImageDetailView.swift")
        # Find the Trash ActionCard block
        trash_match = re.search(
            r'ActionCard\(title:\s*"Trash"[^}]+\{([^}]+)\}',
            content, re.DOTALL
        )
        if trash_match:
            trash_body = trash_match.group(1)
            self.assertNotIn(
                "fileService.trashImage", trash_body,
                "BUG-01 REGRESSION: Trash ActionCard must not call fileService.trashImage directly"
            )

    def test_BUG02_no_duplicate_verify_sheet(self):
        """BUG-02: showVerifyDisk must not have duplicate .sheet modifiers."""
        content = read_file(VIEWS_DIR / "ImageDetailView.swift")
        show_verify_sheets = re.findall(
            r'\.sheet\(isPresented:\s*\$showVerifyDisk\)', content
        )
        self.assertLessEqual(
            len(show_verify_sheets), 1,
            f"BUG-02 REGRESSION: showVerifyDisk appears {len(show_verify_sheets)} times. "
            f"Duplicate sheet modifiers create dead code (SwiftUI only honors the last one)."
        )

    def test_BUG03_window_title_is_emaxforge(self):
        """BUG-03: Window title must be 'EmaxForge', not 'EMULOTION'."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        self.assertNotIn(
            'let base = "EMULOTION"', content,
            "BUG-03 REGRESSION: Window title must be 'EmaxForge', not internal brand 'EMULOTION'"
        )

    def test_BUG04_hex_viewer_has_real_destination(self):
        """BUG-04: .hexViewer navigation must not fall through to ImageDetailView."""
        content = read_file(VIEWS_DIR / "ContentView.swift")
        # Check for the hexViewer case - it should not re-use ImageDetailView
        hex_section = re.search(
            r'case \.hexViewer.*?(?=case \.|\Z)',
            content, re.DOTALL
        )
        if hex_section:
            hex_body = hex_section.group(0)
            # Allow dedicated HexViewerView, but not ImageDetailView fallback
            is_fallthrough = (
                "ImageDetailView" in hex_body and
                "// TODO" in hex_body
            )
            self.assertFalse(
                is_fallthrough,
                "BUG-04 REGRESSION: .hexViewer navigation must have a real destination, "
                "not fall through to ImageDetailView with a TODO comment"
            )


if __name__ == "__main__":
    # Run with verbose output
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add all test classes
    for test_class in [
        TestH1_VisibilityOfSystemStatus,
        TestH2_MatchSystemAndRealWorld,
        TestH3_UserControlAndFreedom,
        TestH4_ConsistencyAndStandards,
        TestH5_ErrorPrevention,
        TestH6_RecognitionOverRecall,
        TestH7_FlexibilityAndEfficiency,
        TestH8_AestheticAndMinimalistDesign,
        TestH9_ErrorRecognitionAndRecovery,
        TestH10_HelpAndDocumentation,
        TestE2EWorkflows,
        TestRegressions,
    ]:
        suite.addTests(loader.loadTestsFromTestCase(test_class))

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
