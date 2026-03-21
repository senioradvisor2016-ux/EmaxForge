-- Dump accessible UI elements from EmaxForge
-- Returns a text description of visible UI hierarchy
on run argv
    tell application "EmaxForge" to activate
    delay 0.5
    
    set output to ""
    
    tell application "System Events"
        tell process "EmaxForge"
            set frontmost to true
            delay 0.3
            
            -- Window info
            set winPos to position of window 1
            set winSize to size of window 1
            set output to output & "Window: " & (item 1 of winPos) & "," & (item 2 of winPos) & " size: " & (item 1 of winSize) & "x" & (item 2 of winSize) & linefeed
            
            -- Menu bar items
            set output to output & "Menu items: "
            try
                set menuNames to name of every menu bar item of menu bar 1
                repeat with m in menuNames
                    set output to output & m & ", "
                end repeat
            end try
            set output to output & linefeed
            
            -- Top-level UI elements
            set topElements to every UI element of window 1
            repeat with elem in topElements
                try
                    set r to role of elem
                    set d to description of elem
                    set p to position of elem
                    set s to size of elem
                    set output to output & r & " [" & d & "] at " & (item 1 of p) & "," & (item 2 of p) & " size " & (item 1 of s) & "x" & (item 2 of s) & linefeed
                end try
            end repeat
            
            -- Count all accessible elements
            try
                set allCount to count of (entire contents of window 1)
                set output to output & "Total accessible elements: " & allCount & linefeed
            end try
        end tell
    end tell
    
    return output
end run
