-- UI Accessibility Dump
-- Outputs complete UI tree for debugging

set libPath to (path to home folder as text) & "clawd:EmaxForge:tests:applescript:lib.scpt"
set lib to load script file libPath

try
	-- Launch app
	lib's launchEmaxForge()
	delay 2
	
	-- Get UI tree
	tell application "System Events"
		tell process "EmaxForge"
			set uiTree to entire contents of window 1
			
			-- Also get detailed button info
			set buttonList to {}
			repeat with btn in (every button of window 1)
				set btnInfo to {¬
					name:name of btn, ¬
					title:title of btn, ¬
					role:role of btn, ¬
					description:description of btn}
				try
					set axId to value of attribute "AXIdentifier" of btn
					set btnInfo to btnInfo & {identifier:axId}
				end try
				set end of buttonList to btnInfo
			end repeat
			
			-- Get text fields
			set fieldList to {}
			repeat with fld in (every text field of window 1)
				set fldInfo to {¬
					value:value of fld, ¬
					role:role of fld, ¬
					description:description of fld}
				set end of fieldList to fldInfo
			end repeat
			
			-- Get tables/lists
			set tableList to {}
			try
				repeat with tbl in (every table of window 1)
					set tblInfo to {¬
						rowCount:count rows of tbl, ¬
						columnCount:count columns of tbl}
					set end of tableList to tblInfo
				end repeat
			end try
			
			-- Format output
			set output to "=== EMAXFORGE UI DUMP ===" & return & return
			
			set output to output & "BUTTONS (" & (count buttonList) & "):" & return
			repeat with btn in buttonList
				set output to output & "  • " & btn & return
			end repeat
			set output to output & return
			
			set output to output & "TEXT FIELDS (" & (count fieldList) & "):" & return
			repeat with fld in fieldList
				set output to output & "  • " & fld & return
			end repeat
			set output to output & return
			
			set output to output & "TABLES (" & (count tableList) & "):" & return
			repeat with tbl in tableList
				set output to output & "  • " & tbl & return
			end repeat
			set output to output & return
			
			set output to output & "FULL TREE:" & return
			set output to output & (uiTree as text)
			
			-- Write to file
			set dumpFile to (path to home folder as text) & "clawd:EmaxForge:tests:logs:ui-dump.txt"
			set fileRef to open for access file dumpFile with write permission
			set eof fileRef to 0
			write output to fileRef
			close access fileRef
			
			-- Also return for immediate viewing
			return output
		end tell
	end tell
	
on error errMsg
	return "ERROR: " & errMsg
end try
