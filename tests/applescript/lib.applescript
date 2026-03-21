-- EmaxForge AppleScript Test Library
-- Reusable functions for UI automation

-- Launch EmaxForge and wait for window
on launchEmaxForge()
	tell application "EmaxForge"
		activate
		delay 2
	end tell
	
	tell application "System Events"
		repeat until (exists window 1 of process "EmaxForge")
			delay 0.5
		end repeat
	end tell
	
	return true
end launchEmaxForge

-- Get entire UI tree for debugging
on dumpUITree()
	tell application "System Events"
		tell process "EmaxForge"
			return entire contents of window 1
		end tell
	end tell
end dumpUITree

-- Click button by label
on clickButton(buttonLabel)
	tell application "System Events"
		tell process "EmaxForge"
			try
				click button buttonLabel of window 1
				return true
			on error errMsg
				return "ERROR: " & errMsg
			end try
		end tell
	end tell
end clickButton

-- Click button by accessibility identifier
on clickButtonById(buttonId)
	tell application "System Events"
		tell process "EmaxForge"
			try
				set targetButton to first button of window 1 whose value of attribute "AXIdentifier" is buttonId
				click targetButton
				return true
			on error errMsg
				return "ERROR: " & errMsg
			end try
		end tell
	end tell
end clickButtonById

-- Wait for sheet (modal dialog) to appear
on waitForSheet()
	tell application "System Events"
		tell process "EmaxForge"
			repeat 20 times
				if (exists sheet 1 of window 1) then
					return true
				end if
				delay 0.5
			end repeat
		end tell
	end tell
	return false
end waitForSheet

-- Select menu item in popup button
on selectPopupItem(popupLabel, itemText)
	tell application "System Events"
		tell process "EmaxForge"
			try
				-- Find popup by label
				set thePopup to first pop up button of window 1 whose value of attribute "AXDescription" contains popupLabel
				click thePopup
				delay 0.3
				click menu item itemText of menu 1 of thePopup
				return true
			on error errMsg
				return "ERROR: " & errMsg
			end try
		end tell
	end tell
end selectPopupItem

-- Get text from text field
on getTextFieldValue(fieldIndex)
	tell application "System Events"
		tell process "EmaxForge"
			try
				return value of text field fieldIndex of window 1
			on error errMsg
				return "ERROR: " & errMsg
			end try
		end tell
	end tell
end getTextFieldValue

-- Type into text field
on typeIntoField(fieldIndex, textValue)
	tell application "System Events"
		tell process "EmaxForge"
			try
				set focused of text field fieldIndex of window 1 to true
				set value of text field fieldIndex of window 1 to textValue
				return true
			on error errMsg
				return "ERROR: " & errMsg
			end try
		end tell
	end tell
end typeIntoField

-- Check if file exists
on fileExists(filePath)
	tell application "System Events"
		return exists disk item filePath
	end tell
end fileExists

-- Count files in directory
on countFilesInDirectory(dirPath, extension)
	tell application "System Events"
		set fileCount to count (every disk item of folder dirPath whose name extension is extension)
		return fileCount
	end tell
end countFilesInDirectory

-- Verify image file created
on verifyImageCreated(imagePath)
	if fileExists(imagePath) then
		tell application "System Events"
			set fileSize to size of disk item imagePath
			if fileSize > 1000000 then -- At least 1MB
				return true
			else
				return "ERROR: File too small (" & fileSize & " bytes)"
			end if
		end tell
	else
		return "ERROR: File not found at " & imagePath
	end if
end verifyImageCreated

-- Log test result
on logResult(testName, result, details)
	set timestamp to do shell script "date '+%Y-%m-%d %H:%M:%S'"
	set logLine to timestamp & " | " & testName & " | " & result & " | " & details
	
	set logFile to (path to home folder as text) & "clawd:EmaxForge:tests:logs:test-results.log"
	
	try
		set fileRef to open for access file logFile with write permission
		write (logLine & return) to fileRef starting at eof
		close access fileRef
	on error
		try
			close access file logFile
		end try
	end try
	
	return logLine
end logResult

-- Quit EmaxForge
on quitEmaxForge()
	tell application "EmaxForge"
		quit
	end tell
	delay 1
end quitEmaxForge
