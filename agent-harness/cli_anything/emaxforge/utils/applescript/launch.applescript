(*
  launch.applescript
  Launch EmaxForge and wait until the main window is ready.
  Returns: "ready" on success, "timeout" if the app doesn't respond.
*)

property APP_NAME : "EmaxForge"
property LAUNCH_TIMEOUT : 15  -- seconds

on run
    -- Launch or bring to front
    tell application APP_NAME
        activate
    end tell

    -- Wait for main window
    set deadline to (current date) + LAUNCH_TIMEOUT
    repeat
        tell application "System Events"
            tell process APP_NAME
                if (count of windows) > 0 then
                    return "ready"
                end if
            end tell
        end tell

        if (current date) > deadline then
            return "timeout"
        end if
        delay 0.5
    end repeat
end run
