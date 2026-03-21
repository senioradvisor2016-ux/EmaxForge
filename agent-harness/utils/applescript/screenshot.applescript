-- Screenshot EmaxForge window
on run argv
    set outputPath to "/tmp/emaxforge_screenshot.png"
    if (count of argv) > 0 then
        set outputPath to item 1 of argv
    end if
    
    tell application "EmaxForge" to activate
    delay 1
    
    do shell script "/usr/sbin/screencapture -x " & quoted form of outputPath
    return "Screenshot saved to " & outputPath
end run
