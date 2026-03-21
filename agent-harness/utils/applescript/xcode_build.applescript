tell application "Xcode"
    activate
    delay 2
    
    set projectPath to (POSIX path of (path to home folder)) & "clawd/EmaxForge/Package.swift"
    open POSIX file projectPath
    delay 3
    
    -- Build with ⌘B
    tell application "System Events"
        keystroke "b" using command down
    end tell
    
    -- Wait for build
    delay 30
    
    return "Build triggered"
end tell
