(*
  create_boot_disk.applescript
  Automate the BootableDiskWizard via the EmaxForge UI.

  Usage:
      osascript create_boot_disk.applescript [size] [output_path]
      osascript create_boot_disk.applescript "239 MB" "/tmp/HD10.hda"

  Parameters are optional — defaults are used when omitted.
*)

on run argv
    set diskSize to "239 MB"
    set outputPath to ""

    if (count of argv) >= 1 then set diskSize to item 1 of argv
    if (count of argv) >= 2 then set outputPath to item 2 of argv

    -- Ensure EmaxForge is running
    tell application "EmaxForge" to activate
    delay 1

    tell application "System Events"
        tell process "EmaxForge"
            -- Open via menu: Tools > Create Boot Disk…
            tell menu bar 1
                tell menu bar item "Tools"
                    tell menu "Tools"
                        click menu item "Create Boot Disk…"
                    end tell
                end tell
            end tell

            delay 0.8

            -- Find the sheet (wizard)
            set frontWin to front window
            if (count of sheets of frontWin) = 0 then
                return "error: wizard sheet did not appear"
            end if

            tell sheet 1 of frontWin
                -- Select disk size
                set sizePopup to first pop up button
                tell sizePopup
                    click
                    delay 0.3
                    -- Select matching menu item
                    tell menu 1
                        set items to menu items
                        repeat with item_ in items
                            if (title of item_ as string) contains diskSize then
                                click item_
                                exit repeat
                            end if
                        end repeat
                    end tell
                end tell

                delay 0.3

                -- Click "Create" / "Next" / primary button
                set btns to buttons
                repeat with btn in btns
                    set bTitle to title of btn as string
                    if bTitle is in {"Create", "Next", "Create Disk"} then
                        click btn
                        exit repeat
                    end if
                end repeat
            end tell
        end tell
    end tell

    -- Wait for completion (sheet dismissed)
    set deadline to (current date) + 30
    repeat
        tell application "System Events"
            tell process "EmaxForge"
                if (count of sheets of front window) = 0 then
                    return "done"
                end if
            end tell
        end tell
        if (current date) > deadline then
            return "timeout"
        end if
        delay 1
    end repeat
end run
