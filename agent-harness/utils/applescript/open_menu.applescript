-- Open a menu item in EmaxForge
-- Usage: osascript open_menu.applescript "Tools" "Format Disk…"
on run argv
    if (count of argv) < 1 then
        return "Usage: open_menu.applescript <menu_name> [menu_item]"
    end if
    
    set menuName to item 1 of argv
    
    tell application "EmaxForge" to activate
    delay 0.5
    
    tell application "System Events"
        tell process "EmaxForge"
            set frontmost to true
            delay 0.3
            
            if (count of argv) > 1 then
                set menuItem to item 2 of argv
                click menu item menuItem of menu menuName of menu bar 1
                return "Clicked: " & menuName & " > " & menuItem
            else
                -- Just list menu items
                set output to "Menu '" & menuName & "' items:" & linefeed
                try
                    set items to name of every menu item of menu menuName of menu bar 1
                    repeat with i in items
                        if i is not missing value then
                            set output to output & "  - " & i & linefeed
                        else
                            set output to output & "  ---" & linefeed
                        end if
                    end repeat
                end try
                return output
            end if
        end tell
    end tell
end run
