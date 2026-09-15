import XCTest
@testable import CheapSeek

final class AppSettingsTests: XCTestCase {

    private let timeZoneKey = "settings.timeZone"
    private let notificationsKey = "settings.notificationsEnabled"
    private let updateIntervalKey = "settings.updateInterval"

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testDefaultValues() {
        let settings = AppSettings(defaults: makeDefaults())

        XCTAssertEqual(settings.timeZoneIdentifier, AppSettings.systemTimeZoneIdentifier)
        XCTAssertFalse(settings.notificationsEnabled)
        XCTAssertEqual(settings.updateInterval, AppSettings.defaultUpdateInterval)
    }

    func testTimeZoneResolution() {
        let defaults = makeDefaults()

        defaults.set("UTC", forKey: timeZoneKey)
        XCTAssertEqual(AppSettings(defaults: defaults).timeZone, TimeZone(identifier: "UTC"))

        defaults.set("", forKey: timeZoneKey)
        XCTAssertEqual(AppSettings(defaults: defaults).timeZone, .current)

        defaults.set("Not/AZone", forKey: timeZoneKey)
        XCTAssertEqual(AppSettings(defaults: defaults).timeZone, .current)
    }

    func testUpdateIntervalIsClampedToRange() {
        let defaults = makeDefaults()

        defaults.set(500.0, forKey: updateIntervalKey)
        XCTAssertEqual(AppSettings(defaults: defaults).updateInterval, 300)

        defaults.set(5.0, forKey: updateIntervalKey)
        XCTAssertEqual(AppSettings(defaults: defaults).updateInterval, 30)
    }

    func testPersistenceAcrossInstances() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.timeZoneIdentifier = "Asia/Istanbul"
        settings.notificationsEnabled = true
        settings.updateInterval = 120

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.timeZoneIdentifier, "Asia/Istanbul")
        XCTAssertTrue(reloaded.notificationsEnabled)
        XCTAssertEqual(reloaded.updateInterval, 120)
    }
}
