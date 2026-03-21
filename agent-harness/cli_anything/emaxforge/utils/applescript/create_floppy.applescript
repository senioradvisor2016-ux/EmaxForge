(*
  create_floppy.applescript
  Automate the CreateFloppySheet via EmaxForge UI.

  Usage:
      osascript create_floppy.applescript [density]
      density: "800 KB" (default), "180 KB", "1.44 MB"
*)

on run argv
    set density to "800 KB"
    if (count of argv) >= 1 then set density to item 1 of argv

    tell application "EmaxForge" to activate
    delay 1

    tell application "System Events"
        tell process "EmaxForge"
            -- File > New Floppy… or Tools menu
            try
                tell menu bar 1
                    tell menu bar item "File"
                        tell menu "File"
                            click menu item "New Floppy Image…"
                        end tell
                    end tell
                end tell
            on error
                tell menu bar 1
                    tell menu bar item "Tools"
                        tell menu "Tools"
                            click menu item "Create Floppy Image…"
                        end tell
                    end tell
                end tell
            end try

            delay 0.8

            set frontWin to front window
            if (count of sheets of frontWin) = 0 then
                return "error: sheet did not appear"
            end if

            tell sheet 1 of frontWin
                -- Select density radio button
                set radioGroup to first radio group
                tell radioGroup
                    set radioButtons to radio buttons
                    repeat with rb in radioButtons
                        if (title of rb as string) contains density then
                            click rb
                            exit repeat
                        end if
                    end repeat
                end tell

                delay 0.2

                -- Click Create
                set btns to buttons
                repeat with btn in btns
                    if (title of btn as string) is in {"Create Floppy", "Create", "OK"} then
                        click btn
                        exit repeat
                    end if
                end repeat
            end tell
        end tell
    end tell

    delay 2
    return "done"
end run
