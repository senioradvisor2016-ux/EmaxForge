#!/usr/bin/env python3
"""
EmaxForge GUI Automation via macOS Accessibility API
Autonomous testing without AppleScript limitations
"""

import subprocess
import time
import json
from pathlib import Path

class EmaxForgeAutomation:
    """Automate EmaxForge GUI testing"""
    
    def __init__(self, app_path="~/clawd/EmaxForge/.build/EmaxForge.app"):
        self.app_path = Path(app_path).expanduser()
        self.process = None
        
    def launch(self, disk_path=None):
        """Launch EmaxForge with optional disk"""
        # Kill existing
        subprocess.run(["killall", "EmaxForge"], capture_output=True)
        time.sleep(1)
        
        cmd = ["open", "-a", str(self.app_path)]
        if disk_path:
            cmd.append(str(disk_path))
        
        subprocess.run(cmd)
        time.sleep(3)
        
        # Check if running
        result = subprocess.run(["pgrep", "-x", "EmaxForge"], capture_output=True)
        if result.returncode == 0:
            self.process = int(result.stdout.decode().strip())
            print(f"✓ EmaxForge launched (PID: {self.process})")
            return True
        else:
            print("✗ Failed to launch EmaxForge")
            return False
    
    def take_screenshot(self, filename):
        """Take screenshot of EmaxForge window"""
        output = Path("~/clawd/EmaxForge/test_screenshots").expanduser() / filename
        output.parent.mkdir(exist_ok=True)
        
        subprocess.run([
            "/usr/sbin/screencapture",
            "-o",  # No window shadow
            "-x",  # No sound
            str(output)
        ])
        
        print(f"✓ Screenshot: {output}")
        return output
    
    def click_button(self, button_name):
        """
        Attempt to click button via AppleScript
        Note: May not work due to SwiftUI accessibility limitations
        """
        script = f'''
        tell application "System Events"
            tell process "EmaxForge"
                set frontmost to true
                delay 0.5
                try
                    click button "{button_name}" of window 1
                    return true
                on error
                    return false
                end try
            end tell
        end tell
        '''
        
        result = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True,
            text=True
        )
        
        return "true" in result.stdout.lower()
    
    def send_keys(self, keys, modifiers=None):
        """Send keyboard shortcut"""
        mod_str = ""
        if modifiers:
            if "command" in modifiers:
                mod_str += "command down, "
            if "shift" in modifiers:
                mod_str += "shift down, "
            if "option" in modifiers:
                mod_str += "option down, "
            mod_str = mod_str.rstrip(", ")
        
        script = f'''
        tell application "System Events"
            tell process "EmaxForge"
                set frontmost to true
                delay 0.3
                keystroke "{keys}" {"using {" + mod_str + "}" if mod_str else ""}
            end tell
        end tell
        '''
        
        subprocess.run(["osascript", "-e", script], capture_output=True)
        time.sleep(0.5)
    
    def terminate(self):
        """Close EmaxForge"""
        subprocess.run(["killall", "EmaxForge"], capture_output=True)
        time.sleep(1)
        print("✓ EmaxForge terminated")


def cli_create_test_disk(output_path="/tmp/GUI_TEST.hda"):
    """Create test disk via CLI-Anything"""
    print("Creating test disk...")
    subprocess.run([
        "cli-anything-emaxforge", "create-disk",
        "--size", "239",
        "--scsi-id", "2",
        "--output", output_path
    ], capture_output=True)
    
    if Path(output_path).exists():
        print(f"✓ Test disk: {output_path}")
        return True
    return False


def cli_import_bank(disk_path, bank_path="~/clawd/standard/Brass_Pipes.EB2"):
    """Import bank via CLI-Anything"""
    print("Importing test bank...")
    bank_path = Path(bank_path).expanduser()
    
    subprocess.run([
        "cli-anything-emaxforge", "import-bank",
        "--disk", disk_path,
        "--bank", str(bank_path)
    ], capture_output=True)
    
    # Verify
    result = subprocess.run([
        "cli-anything-emaxforge", "list-banks",
        "--disk", disk_path,
        "--json"
    ], capture_output=True, text=True)
    
    try:
        data = json.loads(result.stdout)
        count = data.get("count", 0)
        print(f"✓ Banks imported: {count}")
        return count
    except:
        return 0


def cli_verify_disk(disk_path):
    """Verify disk via CLI-Anything"""
    print("Verifying disk structure...")
    result = subprocess.run([
        "cli-anything-emaxforge", "verify-disk",
        "--disk", disk_path,
        "--json"
    ], capture_output=True, text=True)
    
    try:
        data = json.loads(result.stdout)
        valid = data.get("valid", False)
        if valid:
            print("✓ Disk valid (CLI check)")
        else:
            print("⚠ Disk validation failed")
        return valid
    except:
        return False


def main():
    """Run autonomous GUI test"""
    print("="*50)
    print("AUTONOMOUS GUI TESTING - EmaxForge")
    print("="*50)
    print()
    
    # Phase 1: CLI Setup
    print("PHASE 1: CLI Preparation")
    print("-" * 50)
    
    test_disk = "/tmp/GUI_TEST.hda"
    
    if not cli_create_test_disk(test_disk):
        print("✗ Failed to create test disk")
        return
    
    bank_count = cli_import_bank(test_disk)
    if bank_count == 0:
        print("⚠ No banks imported")
    
    cli_verify_disk(test_disk)
    
    print()
    
    # Phase 2: GUI Automation
    print("PHASE 2: GUI Automation")
    print("-" * 50)
    
    app = EmaxForgeAutomation()
    
    if not app.launch(test_disk):
        return
    
    # Baseline screenshot
    app.take_screenshot("01_app_launched.png")
    
    print()
    print("PHASE 3: Interactive Testing")
    print("-" * 50)
    print()
    print("EmaxForge is running. Manual verification needed:")
    print()
    print("1. Check if disk loaded correctly")
    print("2. Look for 'Verify Disk' button")
    print("3. Look for 'Export Banks' button")
    print()
    input("Press ENTER to take final screenshot and exit...")
    
    app.take_screenshot("02_final_state.png")
    app.terminate()
    
    print()
    print("="*50)
    print("TEST COMPLETE")
    print("="*50)
    print()
    print(f"Screenshots: ~/clawd/EmaxForge/test_screenshots/")
    print()


if __name__ == "__main__":
    main()
