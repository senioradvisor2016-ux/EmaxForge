import XCTest

/// UI Tests for EmaxForge
/// Automated GUI testing for standard tools validation features
final class EmaxForgeUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
    }
    
    // MARK: - Verify Disk Tests
    
    func testVerifyDiskButtonExists() throws {
        // Wait for app to load
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        
        // Check for "Verify Disk" button
        let verifyButton = app.buttons["Verify Disk"]
        XCTAssertTrue(verifyButton.exists, "Verify Disk button should exist")
    }
    
    func testVerifyDiskWorkflow() throws {
        // Load test disk first (TODO: automate file opening)
        // For now, assume disk is loaded
        
        let verifyButton = app.buttons["Verify Disk"]
        XCTAssertTrue(verifyButton.waitForExistence(timeout: 5))
        
        // Click button
        verifyButton.tap()
        
        // Wait for sheet
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        
        // Check for validation results
        let validCheckmark = app.images["checkmark.seal.fill"]
        XCTAssertTrue(validCheckmark.waitForExistence(timeout: 5))
        
        // Check for "Done" button
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists)
        doneButton.tap()
    }
    
    // MARK: - Export Banks Tests
    
    func testExportBanksButtonExists() throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        
        let exportButton = app.buttons["Export Banks"]
        XCTAssertTrue(exportButton.exists, "Export Banks button should exist")
    }
    
    func testExportBanksWorkflow() throws {
        let exportButton = app.buttons["Export Banks"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        
        // Click button
        exportButton.tap()
        
        // Wait for sheet
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        
        // Check for bank list
        let bankList = app.scrollViews.firstMatch
        XCTAssertTrue(bankList.exists)
        
        // Check for "Cancel" button
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()
    }
    
    // MARK: - Round-trip Tests
    
    func testVerifyThenExport() throws {
        // 1. Verify disk
        let verifyButton = app.buttons["Verify Disk"]
        XCTAssertTrue(verifyButton.waitForExistence(timeout: 5))
        verifyButton.tap()
        
        let verifySheet = app.sheets.firstMatch
        XCTAssertTrue(verifySheet.waitForExistence(timeout: 3))
        
        app.buttons["Done"].tap()
        
        // 2. Export banks
        let exportButton = app.buttons["Export Banks"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 2))
        exportButton.tap()
        
        let exportSheet = app.sheets.firstMatch
        XCTAssertTrue(exportSheet.waitForExistence(timeout: 3))
        
        app.buttons["Cancel"].tap()
    }
}
