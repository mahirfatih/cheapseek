import XCTest

// UI test audit (macOS 26.6.2 / Build 25G83 tested; macOS 14+ target) — 7 tests, 0 skips:
// - testAppLaunches ................... assert — app is running after launch.
// - testSettingsOpensAndListsLanguages  assert — Settings is shown in a plain window under
//                                                `-UITestSettings` and the language picker lists
//                                                exactly 17 languages.
// - testSettingsTimezonePickerOpens ... assert — the timezone picker opens and its search field
//                                                filters the list.
// - testQuitMenuItemExists ............ assert — the Quit command (⌘Q) terminates the app.
// - testPopupOpensAndShowsStatus ...... assert — `-UITestMode` presents the popup in a plain
//                                                window; the status badge, countdown, and history
//                                                toggle/chart are asserted.
// - testPopupPricingSheetOpens ........ assert — the popup's pricing button opens the pricing
//                                                view with at least one model row.
// - testPopupQuitButtonExists ......... assert — the popup's quit button exists and is hittable.
//
// A menu-bar-only agent (LSUIElement) has no hittable menu bar and macOS exposes no public API
// to open the MenuBarExtra popup, so `-UITestMode` (popup) and `-UITestSettings` (Settings)
// present those surfaces in plain windows for UI testing. These flags are test-only.
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

        let clearHistory = firstElement(app, identifier: "settings.clearHistory")
        XCTAssertTrue(clearHistory.waitForExistence(timeout: 10), "Clear history action missing")

        let about = firstElement(app, identifier: "settings.about")
        XCTAssertTrue(about.waitForExistence(timeout: 10), "About button missing")
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

    func testPopupOpensAndShowsStatus() {
        let app = launch()

        let root = firstElement(app, identifier: "popup.root")
        XCTAssertTrue(root.waitForExistence(timeout: 10), "Popup did not open")

        let badge = firstElement(app, identifier: "popup.status")
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "Popup status badge missing")
        let status = (badge.value as? String) ?? ""
        XCTAssertTrue(["peak", "offPeak"].contains(status),
                      "Popup status should report peak/off-peak, got \(status)")

        let countdown = firstElement(app, identifier: "popup.countdown")
        XCTAssertTrue(countdown.waitForExistence(timeout: 5), "Popup countdown missing")

        let toggle = firstElement(app, identifier: "popup.history.toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "History toggle missing")

        let chart = firstElement(app, identifier: "popup.history.chart")
        if !chart.exists {
            toggle.click()
        }
        XCTAssertTrue(chart.waitForExistence(timeout: 5), "History chart did not appear")

        let about = firstElement(app, identifier: "popup.about.button")
        XCTAssertTrue(about.waitForExistence(timeout: 5), "About button missing")
    }

    func testPopupPricingSheetOpens() {
        let app = launch()

        let pricingButton = firstElement(app, identifier: "popup.pricing.button")
        XCTAssertTrue(pricingButton.waitForExistence(timeout: 10), "Pricing button missing")
        pricingButton.click()

        let pricingRoot = firstElement(app, identifier: "pricing.root")
        XCTAssertTrue(pricingRoot.waitForExistence(timeout: 10), "Pricing view did not open")

        let modelRow = app.staticTexts["DeepSeek-V4.1-Flash"]
        XCTAssertTrue(modelRow.waitForExistence(timeout: 5), "Pricing model row missing")
    }

    func testPopupQuitButtonExists() {
        let app = launch()

        let quitButton = firstElement(app, identifier: "popup.quit.button")
        XCTAssertTrue(quitButton.waitForExistence(timeout: 10), "Quit button missing")
        XCTAssertTrue(quitButton.isHittable, "Quit button should be hittable")
    }

    // MARK: - Helpers

    private func launch(settingsWindow: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        // `-UITestMode` disables real notifications/launch-at-login and presents the
        // popup in a plain window; `-UITestSettings` additionally opens Settings.
        app.launchArguments = ["-UITestMode", "1"]
        if settingsWindow {
            app.launchArguments.append("-UITestSettings")
        }
        app.launch()
        return app
    }

    private func firstElement(_ app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
