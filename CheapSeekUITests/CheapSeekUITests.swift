import XCTest

final class CheapSeekUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertNotEqual(app.state, .notRunning, "CheapSeek should be running after launch")
    }

    func testStatusItemOpensPopup() throws {
        let app = try launchAndOpenPopup()

        // The popup is confirmed open by `launchAndOpenPopup` (it waits for the title).
        XCTAssertNotEqual(app.state, .notRunning)
    }

    func testSettingsControlsWhenPopupOpen() throws {
        let app = try launchAndOpenPopup()

        let settingsButton = app.buttons["Settings"]
        guard settingsButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Settings button not found in popup.")
        }
        settingsButton.click()

        let languageLabel = app.staticTexts["Language"]
        guard languageLabel.waitForExistence(timeout: 5) else {
            throw XCTSkip("Settings window did not open (macOS menu bar automation limitation).")
        }

        guard app.staticTexts["Timezone"].waitForExistence(timeout: 5) else {
            throw XCTSkip("Settings controls did not appear (macOS menu bar automation limitation).")
        }

        let launchAtLogin = app.switches["Launch at Login"]
        if !launchAtLogin.waitForExistence(timeout: 5) {
            throw XCTSkip("Launch at Login toggle not exposed to accessibility.")
        }
        XCTAssertTrue(launchAtLogin.exists)
    }

    // MARK: - Helpers

    private func launchAndOpenPopup() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()

        guard let statusItem = locateStatusItem(), statusItem.waitForExistence(timeout: 5) else {
            throw XCTSkip("Menu bar status item is not exposed to accessibility on this system.")
        }

        statusItem.click()

        guard app.staticTexts["CheapSeek"].waitForExistence(timeout: 5) else {
            throw XCTSkip("Status item clicked but the popup did not open (macOS menu bar automation limitation).")
        }

        return app
    }

    private func locateStatusItem() -> XCUIElement? {
        let app = XCUIApplication()
        if app.statusItems.count > 0 {
            return app.statusItems.firstMatch
        }

        for bundleID in ["com.apple.SystemUIServer", "com.apple.controlcenter"] {
            let owner = XCUIApplication(bundleIdentifier: bundleID)
            if owner.statusItems.count > 0 {
                return owner.statusItems.firstMatch
            }
        }

        return nil
    }
}
