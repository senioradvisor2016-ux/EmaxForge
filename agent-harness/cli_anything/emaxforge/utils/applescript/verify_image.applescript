(*
  verify_image.applescript
  Read the inspector panel / image list to verify a disk image is shown
  in the EmaxForge UI with expected properties.

  Returns JSON-like string: {"found": true, "name": "HD10.hda", "size": "239 MB"}
*)

on run argv
    set targetName to ""
    if (count of argv) >= 1 then set targetName to item 1 of argv

    tell application "EmaxForge" to activate
    delay 0.5

    tell application "System Events"
        tell process "EmaxForge"
            -- Look in the main window's table/list for the image
            set frontWin to front window
            set foundName to ""
            set foundSize to ""

            -- Try to find a table or outline (image list)
            try
                set tableElem to first table of scroll area 1 of group 1 of frontWin
                set rowCount to count of rows of tableElem
                repeat with r from 1 to rowCount
                    set rowRef to row r of tableElem
                    set cellVals to value of static texts of rowRef
                    set rowText to cellVals as string
                    if targetName is "" or rowText contains targetName then
                        if (count of cellVals) >= 1 then
                            set foundName to item 1 of cellVals as string
                        end if
                        if (count of cellVals) >= 2 then
                            set foundSize to item 2 of cellVals as string
                        end if
                        exit repeat
                    end if
                end repeat
            end try

            if foundName is "" then
                return "{\"found\": false, \"name\": \"\", \"size\": \"\"}"
            end if

            return "{\"found\": true, \"name\": \"" & foundName & "\", \"size\": \"" & foundSize & "\"}"
        end tell
    end tell
end run
