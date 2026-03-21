-- Click on a disk image in the list by index (1-based)
-- Usage: osascript click_image.applescript 1  (clicks first image)
on run argv
    set imageIndex to 1
    if (count of argv) > 0 then
        set imageIndex to (item 1 of argv) as integer
    end if
    
    tell application "EmaxForge" to activate
    delay 0.5
    
    tell application "System Events"
        tell process "EmaxForge"
            set frontmost to true
            delay 0.3
            
            -- Image list Y positions (approximate, based on 1920x985 window)
            -- Header+toolbar: ~77px, sidebar header: ~30px, search bar: ~40px
            -- First row starts at ~310px, row height ~50px
            set baseY to 310
            set rowHeight to 50
            set targetY to baseY + ((imageIndex - 1) * rowHeight)
            
            -- Image list X center (between sidebar ~250px and detail ~700px)
            set targetX to 480
        end tell
    end tell
    
    -- Use cliclick for pixel-accurate click
    do shell script "/opt/homebrew/bin/cliclick c:" & targetX & "," & targetY
    delay 1
    
    return "Clicked image at index " & imageIndex & " (x:" & targetX & ", y:" & targetY & ")"
end run
