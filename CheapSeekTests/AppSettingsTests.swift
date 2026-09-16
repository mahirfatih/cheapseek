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

    func testNotificationDefaults() {
        let settings = AppSettings(defaults: makeDefaults())

        XCTAssertEqual(settings.notifyBeforePeakMinutes, 5)
        XCTAssertTrue(settings.notifyOnOffPeakStart)
        XCTAssertFalse(settings.notifyOnPeakStart)
        XCTAssertFalse(settings.quietHoursEnabled)
        XCTAssertEqual(settings.quietHoursStart, 23 * 60)
        XCTAssertEqual(settings.quietHoursEnd, 7 * 60)
    }

    func testNotificationPreferencesPersistAndClamp() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.notifyBeforePeakMinutes = 15
        settings.notifyOnPeakStart = true
        settings.quietHoursEnabled = true
        settings.quietHoursStart = 4 * 60
        settings.quietHoursEnd = 10 * 60

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.notifyBeforePeakMinutes, 15)
        XCTAssertTrue(reloaded.notifyOnPeakStart)
        XCTAssertTrue(reloaded.quietHoursEnabled)
        XCTAssertEqual(reloaded.quietHoursStart, 4 * 60)
        XCTAssertEqual(reloaded.quietHoursEnd, 10 * 60)

        XCTAssertEqual(AppSettings.normalizedMinutes(-30), 1410)
        XCTAssertEqual(AppSettings.normalizedMinutes(1500), 60)
    }
}
