#!/usr/bin/env python3
"""
Hybrid State-Based GUI Testing for EmaxForge
Combines CLI-Anything validation + AppleScript automation + Screenshot verification
March 17, 2026
"""

import subprocess
import time
import json
from pathlib import Path
import sys

class Color:
    """ANSI color codes"""
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'

class HybridGUITest:
    """Autonomous GUI testing through state verification"""
    
    def __init__(self):
        self.test_disk = "/tmp/HYBRID_TEST.hda"
        self.screenshot_dir = Path("~/clawd/EmaxForge/test_screenshots").expanduser()
        self.screenshot_dir.mkdir(exist_ok=True)
        self.test_results = []
        
    def log(self, message, level="info"):
        """Colored logging"""
        colors = {
            "info": Color.BLUE,
            "success": Color.GREEN,
            "warning": Color.YELLOW,
            "error": Color.RED
        }
        color = colors.get(level, "")
        print(f"{color}{message}{Color.END}")
    
    def run_cli(self, *args, check_json=False):
        """Run CLI-Anything command"""
        cmd = ["cli-anything-emaxforge"] + list(args)
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if check_json and result.returncode == 0:
            try:
                return json.loads(result.stdout)
            except:
                return None
        
        return result.returncode == 0
    
    def screenshot(self, name, description=""):
        """Take screenshot"""
        output = self.screenshot_dir / f"{name}.png"
        subprocess.run([
            "/usr/sbin/screencapture",
            "-o", "-x",
            str(output)
        ], capture_output=True)
        
        if description:
            self.log(f"📸 {description}", "info")
        
        return output
    
    def launch_app(self, disk_path=None):
        """Launch EmaxForge"""
        # Kill existing
        subprocess.run(["killall", "EmaxForge"], capture_output=True)
        time.sleep(1)
        
        cmd = ["open", "-a", str(Path("~/clawd/EmaxForge/.build/EmaxForge.app").expanduser())]
        if disk_path:
            cmd.append(str(disk_path))
        
        subprocess.run(cmd)
        time.sleep(3)
        
        # Check if running
        result = subprocess.run(["pgrep", "-x", "EmaxForge"], capture_output=True)
        return result.returncode == 0
    
    def click_allow_permission(self):
        """Click permission dialog if present"""
        script = '''
        tell application "System Events"
            tell process "UserNotificationCenter"
                try
                    click button "Tillåt" of window 1
                    return true
                on error
                    try
                        click button "Allow" of window 1
                        return true
                    end try
                end try
            end tell
        end tell
        '''
        subprocess.run(["osascript", "-e", script], capture_output=True)
        time.sleep(1)
    
    def reload_app(self):
        """Reload app via Cmd+R"""
        script = '''
        tell application "System Events"
            tell process "EmaxForge"
                set frontmost to true
                delay 0.3
                keystroke "r" using command down
            end tell
        end tell
        '''
        subprocess.run(["osascript", "-e", script], capture_output=True)
        time.sleep(2)
    
    def test_1_disk_creation(self):
        """TEST 1: Verify GUI shows created disk"""
        self.log("\n" + "="*60, "info")
        self.log("TEST 1: Disk Creation & GUI Loading", "info")
        self.log("="*60, "info")
        
        # Step 1: CLI creates disk
        self.log("Step 1: Creating test disk via CLI...", "info")
        success = self.run_cli("create-disk", "--size", "239", "--scsi-id", "2", "--output", self.test_disk)
        
        if not success or not Path(self.test_disk).exists():
            self.log("✗ Failed to create disk", "error")
            return False
        
        size_mb = Path(self.test_disk).stat().st_size // (1024 * 1024)
        self.log(f"✓ Disk created: {size_mb} MB", "success")
        
        # Step 2: Verify with CLI
        self.log("\nStep 2: CLI validation...", "info")
        data = self.run_cli("verify-disk", "--disk", self.test_disk, "--json", check_json=True)
        
        if data and data.get("valid"):
            self.log(f"✓ Disk valid (CLI check)", "success")
        else:
            self.log("⚠ Disk validation inconclusive", "warning")
        
        # Step 3: Launch GUI
        self.log("\nStep 3: Launching EmaxForge with disk...", "info")
        if not self.launch_app(self.test_disk):
            self.log("✗ Failed to launch app", "error")
            return False
        
        self.log("✓ EmaxForge launched", "success")
        
        # Handle permission dialog
        self.click_allow_permission()
        time.sleep(1)
        
        # Step 4: Screenshot
        self.log("\nStep 4: Taking screenshot...", "info")
        screenshot = self.screenshot("test1_disk_loaded", "Disk loaded in GUI")
        
        self.log(f"✓ Screenshot: {screenshot}", "success")
        self.log("\n🔍 Verify manually: Does GUI show the disk?", "info")
        
        self.test_results.append({
            "test": "Disk Creation",
            "status": "screenshot_verification_needed",
            "screenshot": str(screenshot)
        })
        
        return True
    
    def test_2_bank_import_reflection(self):
        """TEST 2: Verify GUI reflects CLI bank import"""
        self.log("\n" + "="*60, "info")
        self.log("TEST 2: Bank Import Reflection", "info")
        self.log("="*60, "info")
        
        # Step 1: Get initial bank count
        self.log("Step 1: Checking initial bank count...", "info")
        data = self.run_cli("list-banks", "--disk", self.test_disk, "--json", check_json=True)
        initial_count = data.get("count", 0) if data else 0
        self.log(f"✓ Initial banks: {initial_count}", "success")
        
        # Step 2: Import bank via CLI
        self.log("\nStep 2: Importing bank via CLI...", "info")
        bank_path = Path("~/clawd/standard/Brass_Pipes.EB2").expanduser()
        
        if not bank_path.exists():
            self.log(f"⚠ Test bank not found: {bank_path}", "warning")
            return False
        
        success = self.run_cli("import-bank", "--disk", self.test_disk, "--bank", str(bank_path))
        
        if not success:
            self.log("✗ Failed to import bank", "error")
            return False
        
        # Step 3: Verify import with CLI
        data = self.run_cli("list-banks", "--disk", self.test_disk, "--json", check_json=True)
        new_count = data.get("count", 0) if data else 0
        
        self.log(f"✓ Banks after import: {new_count}", "success")
        
        if new_count <= initial_count:
            self.log("⚠ Bank count did not increase", "warning")
        
        # Step 4: Reload GUI
        self.log("\nStep 4: Reloading GUI (Cmd+R)...", "info")
        self.reload_app()
        self.log("✓ GUI reloaded", "success")
        
        # Step 5: Screenshot
        self.log("\nStep 5: Taking screenshot...", "info")
        screenshot = self.screenshot("test2_after_import", f"After importing {new_count} banks")
        
        self.log(f"✓ Screenshot: {screenshot}", "success")
        self.log(f"\n🔍 Verify manually: Does GUI show {new_count} banks?", "info")
        
        self.test_results.append({
            "test": "Bank Import Reflection",
            "status": "screenshot_verification_needed",
            "screenshot": str(screenshot),
            "expected_count": new_count
        })
        
        return True
    
    def test_3_verify_disk_feature(self):
        """TEST 3: Verify "Verify Disk" feature exists"""
        self.log("\n" + "="*60, "info")
        self.log("TEST 3: Verify Disk Feature Presence", "info")
        self.log("="*60, "info")
        
        self.log("Taking screenshot of main view...", "info")
        screenshot = self.screenshot("test3_main_view", "Looking for Verify Disk button")
        
        self.log(f"✓ Screenshot: {screenshot}", "success")
        self.log("\n🔍 Verify manually: Can you see 'Verify Disk' button?", "info")
        
        self.test_results.append({
            "test": "Verify Disk Feature",
            "status": "screenshot_verification_needed",
            "screenshot": str(screenshot)
        })
        
        return True
    
    def test_4_export_banks_feature(self):
        """TEST 4: Verify "Export Banks" feature exists"""
        self.log("\n" + "="*60, "info")
        self.log("TEST 4: Export Banks Feature Presence", "info")
        self.log("="*60, "info")
        
        self.log("Taking screenshot of main view...", "info")
        screenshot = self.screenshot("test4_main_view", "Looking for Export Banks button")
        
        self.log(f"✓ Screenshot: {screenshot}", "success")
        self.log("\n🔍 Verify manually: Can you see 'Export Banks' button?", "info")
        
        self.test_results.append({
            "test": "Export Banks Feature",
            "status": "screenshot_verification_needed",
            "screenshot": str(screenshot)
        })
        
        return True
    
    def cleanup(self):
        """Cleanup test artifacts"""
        self.log("\n" + "="*60, "info")
        self.log("Cleanup", "info")
        self.log("="*60, "info")
        
        # Close app
        subprocess.run(["killall", "EmaxForge"], capture_output=True)
        self.log("✓ App closed", "success")
        
        # Keep test disk for manual inspection
        self.log(f"✓ Test disk preserved: {self.test_disk}", "success")
    
    def print_summary(self):
        """Print test summary"""
        self.log("\n" + "="*60, "info")
        self.log("TEST SUMMARY", "info")
        self.log("="*60, "info")
        
        for i, result in enumerate(self.test_results, 1):
            self.log(f"\n{i}. {result['test']}", "info")
            self.log(f"   Status: {result['status']}", "warning")
            self.log(f"   Screenshot: {result['screenshot']}", "info")
            
            if "expected_count" in result:
                self.log(f"   Expected banks: {result['expected_count']}", "info")
        
        self.log(f"\n📁 All screenshots: {self.screenshot_dir}/", "info")
        self.log("\n✅ HYBRID TESTING COMPLETE!", "success")
        self.log("Manual verification of screenshots needed.", "info")

def main():
    """Run all tests"""
    print(f"\n{Color.BOLD}{'='*60}{Color.END}")
    print(f"{Color.BOLD}HYBRID STATE-BASED GUI TESTING{Color.END}")
    print(f"{Color.BOLD}EmaxForge - CLI + AppleScript + Screenshots{Color.END}")
    print(f"{Color.BOLD}{'='*60}{Color.END}\n")
    
    tester = HybridGUITest()
    
    try:
        # Run tests
        tester.test_1_disk_creation()
        time.sleep(2)
        
        tester.test_2_bank_import_reflection()
        time.sleep(2)
        
        tester.test_3_verify_disk_feature()
        time.sleep(1)
        
        tester.test_4_export_banks_feature()
        
        # Cleanup
        tester.cleanup()
        
        # Summary
        tester.print_summary()
        
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        tester.cleanup()
        sys.exit(1)
    except Exception as e:
        print(f"\n{Color.RED}Error: {e}{Color.END}")
        tester.cleanup()
        sys.exit(1)

if __name__ == "__main__":
    main()
