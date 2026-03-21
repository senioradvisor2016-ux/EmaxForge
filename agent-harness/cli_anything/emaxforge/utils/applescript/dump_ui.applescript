(*
  dump_ui.applescript
  Dump the full accessibility hierarchy of EmaxForge's front window.
  Useful for debugging automation scripts.

  Returns plain text hierarchy.
*)

on run
    tell application "EmaxForge" to activate
    delay 0.5

    set output to ""
    tell application "System Events"
        tell process "EmaxForge"
            set frontWin to front window
            set output to my dumpElement(frontWin, 0)
        end tell
    end tell
    return output
end run

on dumpElement(elem, depth)
    set indent to ""
    repeat depth times
        set indent to indent & "  "
    end repeat

    set elemClass to class of elem as string
    set elemName to ""
    try
        set elemName to name of elem as string
    end try
    set elemDesc to ""
    try
        set elemDesc to description of elem as string
    end try
    set elemRole to ""
    try
        set elemRole to role of elem as string
    end try

    set line to indent & "[" & elemRole & "] " & elemName
    if elemDesc is not "" then
        set line to line & " (" & elemDesc & ")"
    end if
    set output to line & return

    set children to {}
    try
        set children to UI elements of elem
    end try
    repeat with child in children
        set output to output & my dumpElement(child, depth + 1)
    end repeat

    return output
end dumpElement
