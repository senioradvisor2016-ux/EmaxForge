#!/usr/bin/env python3
"""
Click disk image in EmaxForge list to navigate to ImageDetailView
Uses coordinate-based clicking since AppleScript can't access SwiftUI elements
"""

import subprocess
import time

def get_window_position():
    """Get EmaxForge window position and size"""
    script = '''
    tell application "System Events"
        tell process "EmaxForge"
            set frontmost to true
            delay 0.3
            
            try
                tell window 1
                    set winPos to position
                    set winSize to size
                    return {item 1 of winPos, item 2 of winPos, item 1 of winSize, item 2 of winSize}
                end tell
            on error
                return {0, 0, 0, 0}
            end try
        end tell
    end tell
    '''
    
    result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
    coords = result.stdout.strip().split(", ")
    
    if len(coords) == 4:
        return [int(c) for c in coords]
    return [0, 0, 0, 0]

def click_at_coordinates(x, y, double=False):
    """Click at specific screen coordinates"""
    script = f'''
    tell application "System Events"
        tell process "EmaxForge"
            set frontmost to true
            delay 0.2
        end tell
    end tell
    
    do shell script "cliclick c:{x},{y}"
    '''
    
    subprocess.run(["osascript", "-e", script], capture_output=True)
    
    if double:
        time.sleep(0.1)
        subprocess.run(["osascript", "-e", script], capture_output=True)

def click_disk_in_list():
    """Click HD10.hda disk in the list"""
    print("Getting EmaxForge window position...")
    x, y, w, h = get_window_position()
    
    if w == 0 or h == 0:
        print("❌ Could not get window position")
        return False
    
    print(f"Window: x={x}, y={y}, w={w}, h={h}")
    
    # Calculate click position
    # HD10.hda is typically in the center-right area
    # Approximate: 70% from left, 40% from top
    click_x = x + int(w * 0.7)
    click_y = y + int(h * 0.4)
    
    print(f"Clicking at: ({click_x}, {click_y})")
    
    # Double click to open disk detail view
    click_at_coordinates(click_x, click_y, double=True)
    time.sleep(2)
    
    print("✓ Clicked disk image")
    return True

def main():
    # Check if cliclick is installed
    result = subprocess.run(["which", "cliclick"], capture_output=True)
    if result.returncode != 0:
        print("Installing cliclick...")
        subprocess.run(["brew", "install", "cliclick"], capture_output=True)
    
    if not click_disk_in_list():
        print("❌ Failed to click disk")
        return
    
    # Take screenshot after click
    subprocess.run([
        "/usr/sbin/screencapture",
        "-o", "-x",
        str(Path("~/clawd/EmaxForge/test_screenshots/after_disk_click.png").expanduser())
    ])
    
    print("✓ Screenshot taken: after_disk_click.png")

if __name__ == "__main__":
    from pathlib import Path
    main()
