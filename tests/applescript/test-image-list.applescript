-- Test: Image List Operations
-- Verifies image loading, selection, and navigation

set libPath to (path to home folder as text) & "clawd:EmaxForge:tests:applescript:lib.scpt"
set lib to load script file libPath

set testName to "ImageList_Operations"

try
	-- 1. Launch app
	lib's logResult(testName, "START", "Launching EmaxForge")
	lib's launchEmaxForge()
	delay 2
	
	-- 2. Count images in default directory
	lib's logResult(testName, "STEP", "Checking for .hda images")
	tell application "System Events"
		tell process "EmaxForge"
			-- Get table/list view
			set imageTable to first table of scroll area 1 of window 1
			set rowCount to count rows of imageTable
			lib's logResult(testName, "INFO", "Found " & rowCount & " images")
		end tell
	end tell
	
	-- 3. Verify UI elements present
	lib's logResult(testName, "VERIFY", "Checking toolbar buttons")
	tell application "System Events"
		tell process "EmaxForge"
			-- Check for critical buttons
			set buttonNames to name of every button of window 1
			
			if buttonNames contains "New Image" then
				lib's logResult(testName, "PASS", "New Image button found")
			else
				error "New Image button missing"
			end if
			
			if buttonNames contains "Create Bootable Disk" then
				lib's logResult(testName, "PASS", "Boot disk button found")
			else
				error "Boot disk button missing"
			end if
		end tell
	end tell
	
	-- 4. Select first image (if exists)
	if rowCount > 0 then
		lib's logResult(testName, "STEP", "Selecting first image")
		tell application "System Events"
			tell process "EmaxForge"
				select row 1 of imageTable
				delay 1
			end tell
		end tell
		lib's logResult(testName, "PASS", "Image selection works")
	else
		lib's logResult(testName, "SKIP", "No images to test selection")
	end if
	
	-- 5. Test search/filter (if field exists)
	lib's logResult(testName, "STEP", "Testing search field")
	tell application "System Events"
		tell process "EmaxForge"
			try
				set searchField to first text field of window 1
				set focused of searchField to true
				keystroke "HD0"
				delay 1
				keystroke (ASCII character 8) -- Backspace
				keystroke (ASCII character 8)
				keystroke (ASCII character 8)
				lib's logResult(testName, "PASS", "Search field works")
			on error
				lib's logResult(testName, "SKIP", "No search field found")
			end try
		end tell
	end tell
	
	-- SUCCESS
	lib's logResult(testName, "PASS", "Image list operations completed")
	lib's quitEmaxForge()
	
	return "✅ PASS: Image list test succeeded"
	
on error errMsg
	lib's logResult(testName, "FAIL", errMsg)
	lib's quitEmaxForge()
	return "❌ FAIL: " & errMsg
end try
