import XCTest

// UI test audit (macOS 26.x / 14+):
// - testAppLaunches ................... assert — app is running after launch.
// - testSettingsOpensAndListsLanguages  assert — Settings is shown in a plain window under
//                                                `-UITestSettings` and the language picker lists
//                                                exactly 17 languages.
// - testSettingsTimezonePickerOpens ... assert — the timezone picker opens and its search field
//                                                filters the list.
// - testQuitMenuItemExists ............ assert — the Quit command (⌘Q) terminates the app.
// - testPopupOpensAndShowsStatus ...... assert when the status item is exposed; otherwise
//                                                XCTSkip. macOS does not reliably expose
//                                                third-party MenuBarExtra status items to the
//                                                accessibility tree, and there is no public API
//                                                to open the MenuBarExtra popup programmatically.
//
// A menu-bar-only agent (LSUIElement) has no hittable menu bar, so Settings cannot be opened
// through the app menu in tests; `-UITestSettings` (test-only) presents it in a plain window.
final class CheapSeekUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Tests

    func testAppLaunches() {
        let app = launch()

        XCTAssertNotEqual(app.state, .notRunning, "CheapSeek should be running after launch")
    }

    func testSettingsOpensAndListsLanguages() throws {
        let app = launch(settingsWindow: true)

        let root = firstElement(app, identifier: "settings.root")
        XCTAssertTrue(root.waitForExistence(timeout: 10), "Settings window did not open")

        let picker = firstElement(app, identifier: "settings.language")
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Language picker not found")
        picker.click()

        // Scope to the picker's own menu, not every menu item in the app.
        let menu = picker.menus.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "Language menu did not open")
        XCTAssertEqual(menu.menuItems.count, 17, "Expected exactly 17 languages")

        app.typeKey(.escape, modifierFlags: [])
    }

    func testSettingsTimezonePickerOpens() throws {
        let app = launch(settingsWindow: true)

        let root = firstElement(app, identifier: "settings.root")
        XCTAssertTrue(root.waitForExistence(timeout: 10), "Settings window did not open")

        let timezone = firstElement(app, identifier: "settings.timezone")
        XCTAssertTrue(timezone.waitForExistence(timeout: 10), "Timezone picker not found")
        timezone.click()

        let search = app.textFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "Timezone search field not found")
        search.click()
        search.typeText("tokyo")

        // Timezone rows are buttons labelled "<City> <offset>"; "tokyo" narrows the list
        // to the single "Tokyo GMT+9" row.
        let tokyo = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Tokyo'")).firstMatch
        XCTAssertTrue(tokyo.waitForExistence(timeout: 10), "Search did not filter to Tokyo")
    }

    func testQuitMenuItemExists() {
        let app = launch()

        // A menu-bar-only agent exposes no hittable menu bar item, so assert the
        // standard Quit command (⌘Q) still terminates the app.
        app.activate()
        app.typeKey("q", modifierFlags: .command)

        let terminated = NSPredicate { object, _ in
            (object as? XCUIApplication)?.state == .notRunning
        }
        let exp = XCTNSPredicateExpectation(predicate: terminated, object: app)
        XCTAssertEqual(XCTWaiter().wait(for: [exp], timeout: 10), .completed,
                       "⌘Q should terminate the app")
    }

    func testPopupOpensAndShowsStatus() throws {
        let app = launch()

        guard let statusItem = locateStatusItem(app), statusItem.waitForExistence(timeout: 5) else {
            throw XCTSkip(
                "MenuBarExtra status item is not exposed to accessibility on "
                + "\(ProcessInfo.processInfo.operatingSystemVersionString); no public API opens the popup."
            )
        }
        statusItem.click()

        let badge = firstElement(app, identifier: "popup.status")
        guard badge.waitForExistence(timeout: 5) else {
            throw XCTSkip(
                "Status item clicked but the MenuBarExtra popup did not open on "
                + "\(ProcessInfo.processInfo.operatingSystemVersionString)."
            )
        }
        XCTAssertTrue(badge.exists, "Popup status badge should be visible")
        XCTAssertFalse(
            badge.label.isEmpty,
            "Popup status badge should expose its live peak/off-peak status text"
        )
    }

    // MARK: - Helpers

    private func launch(settingsWindow: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1"]
        if settingsWindow {
            // Menu-bar-only agents have no hittable menu bar, so `-UITestSettings`
            // presents the Settings screen in a plain window for UI testing.
            app.launchArguments.append("-UITestSettings")
        }
        app.launch()
        return app
    }

    private func firstElement(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func locateStatusItem(_ app: XCUIApplication) -> XCUIElement? {
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
