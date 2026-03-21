-- Test: Create Bootable Disk
-- Verifies boot disk wizard creates valid HD00.hda

-- Load library
set libPath to (path to home folder as text) & "clawd:EmaxForge:tests:applescript:lib.scpt"
set lib to load script file libPath

-- Test config
set testName to "BootDisk_Creation"
set outputPath to (path to home folder as text) & "Desktop:TEST_HD00.hda"

-- Cleanup old test file
do shell script "rm -f ~/Desktop/TEST_HD00.hda"

try
	-- 1. Launch app
	lib's logResult(testName, "START", "Launching EmaxForge")
	lib's launchEmaxForge()
	delay 2
	
	-- 2. Open boot disk wizard
	lib's logResult(testName, "STEP", "Opening boot disk wizard")
	set clickResult to lib's clickButton("Create Bootable Disk")
	if clickResult is not true then
		error "Failed to click Create Bootable Disk button: " & clickResult
	end if
	
	-- 3. Wait for wizard sheet
	lib's logResult(testName, "STEP", "Waiting for wizard sheet")
	if not lib's waitForSheet() then
		error "Wizard sheet did not appear"
	end if
	delay 1
	
	-- 4. Select disk size (239 MB)
	lib's logResult(testName, "STEP", "Selecting disk size: 239 MB")
	tell application "System Events"
		tell process "EmaxForge"
			tell sheet 1 of window 1
				-- Find disk size popup
				try
					click pop up button 1
					delay 0.5
					click menu item "239 MB" of menu 1 of pop up button 1
				on error errMsg
					error "Failed to select disk size: " & errMsg
				end try
			end tell
		end tell
	end tell
	delay 1
	
	-- 5. Choose output location
	lib's logResult(testName, "STEP", "Setting output path")
	tell application "System Events"
		tell process "EmaxForge"
			tell sheet 1 of window 1
				-- Click "Choose Location" button
				try
					click button "Choose Location"
					delay 1
					
					-- Handle file dialog (if appears)
					keystroke "g" using {command down, shift down}
					delay 0.5
					keystroke "/Users/senioradvisor/Desktop"
					delay 0.5
					keystroke return
					delay 0.5
					
					-- Type filename
					keystroke "TEST_HD00.hda"
					delay 0.5
					keystroke return
					
				on error errMsg
					-- Path field might be direct input
					lib's logResult(testName, "INFO", "Using direct path input")
				end try
			end tell
		end tell
	end tell
	delay 1
	
	-- 6. Create disk
	lib's logResult(testName, "STEP", "Clicking Create button")
	tell application "System Events"
		tell process "EmaxForge"
			tell sheet 1 of window 1
				click button "Create"
			end tell
		end tell
	end tell
	
	-- 7. Wait for creation (can take 5-10 seconds)
	lib's logResult(testName, "STEP", "Waiting for disk creation (max 15s)")
	delay 15
	
	-- 8. Verify file created
	lib's logResult(testName, "VERIFY", "Checking output file")
	set verifyResult to lib's verifyImageCreated(outputPath)
	if verifyResult is not true then
		error "Verification failed: " & verifyResult
	end if
	
	-- 9. Verify boot structure
	lib's logResult(testName, "VERIFY", "Checking boot signature")
	set bootCheck to do shell script "xxd -l 2 -s 510 ~/Desktop/TEST_HD00.hda | grep '7882'"
	if bootCheck is "" then
		error "Boot signature not found (0x78 0x82 at offset 510)"
	end if
	
	-- 10. Verify FAT entries
	lib's logResult(testName, "VERIFY", "Checking FAT structure")
	set fatCheck to do shell script "xxd -l 4 -s 1024 ~/Desktop/TEST_HD00.hda | grep '0f00 0000'"
	if fatCheck is "" then
		lib's logResult(testName, "WARN", "FAT entry 0 might be incorrect")
	end if
	
	-- SUCCESS!
	lib's logResult(testName, "PASS", "Boot disk created successfully")
	
	-- Cleanup
	lib's quitEmaxForge()
	
	return "✅ PASS: Boot disk test succeeded"
	
on error errMsg
	lib's logResult(testName, "FAIL", errMsg)
	lib's quitEmaxForge()
	return "❌ FAIL: " & errMsg
end try
