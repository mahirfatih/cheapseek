import XCTest
import Localize_Swift
import UserNotifications
@testable import CheapSeek

private final class MockNotificationCenterClient: NotificationCenterClient {
    var status: UNAuthorizationStatus = .authorized
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removeAllCount = 0

    func requestAuthorization(completion: @escaping (Bool) -> Void) { completion(true) }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        completion(status)
    }

    func add(_ requests: [UNNotificationRequest]) {
        addedRequests.append(contentsOf: requests)
    }

    func removeAllPending() {
        removeAllCount += 1
    }
}

@MainActor
final class AppModelTests: XCTestCase {

    private func utcDate(_ year: Int, _ month: Int, _ day: Int,
                         _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components) ?? Date()
    }

    private func makeSettings(timeZoneIdentifier: String = "UTC") -> AppSettings {
        let suite = "AppModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        settings.timeZoneIdentifier = timeZoneIdentifier
        return settings
    }

    private func makeModel(hour: Int) -> AppModel {
        AppModel(
            settings: makeSettings(),
            config: .fallback,
            clock: Clock(now: utcDate(2026, 1, 5, hour, 0)),
            autoStart: false
        )
    }

    func testIsPeakComputedFromInjectedClock() {
        XCTAssertTrue(makeModel(hour: 2).isPeak)
        XCTAssertFalse(makeModel(hour: 12).isPeak)
    }

    func testScheduleUsesSettingsTimeZone() {
        let model = makeModel(hour: 12)

        XCTAssertEqual(model.timeZone, TimeZone(identifier: "UTC"))
        XCTAssertEqual(model.schedule.count, 5)
        XCTAssertEqual(model.schedule[1].isPeak, true)
        XCTAssertEqual(model.schedule[2].isPeak, false)
    }

    func testSetUpdateIntervalClampsToRange() {
        let model = makeModel(hour: 12)
        // Should not crash; the clock is simply restarted with a clamped interval.
        model.setUpdateInterval(1)
        model.setUpdateInterval(1000)
    }

    func testLanguageChangeNotificationIncrementsRevision() {
        let model = makeModel(hour: 12)
        let before = model.languageRevision
        let exp = expectation(description: "language revision increments")

        NotificationCenter.default.post(
            name: Notification.Name(rawValue: LCLLanguageChangeNotification),
            object: nil
        )
        DispatchQueue.main.async { exp.fulfill() }

        wait(for: [exp], timeout: 1)
        XCTAssertGreaterThan(model.languageRevision, before)
    }

    func testBackfillOnLaunchFillsWeekend() {
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: true, at: utcDate(2026, 1, 2, 8)) // Friday peak

        let model = AppModel(
            settings: makeSettings(),
            config: .fallback,
            clock: Clock(now: utcDate(2026, 1, 5, 2)), // Monday peak
            history: store,
            autoStart: false
        )

        XCTAssertEqual(store.samples.map(\.timestamp), [
            utcDate(2026, 1, 2, 8), utcDate(2026, 1, 2, 10),
            utcDate(2026, 1, 5, 1), utcDate(2026, 1, 5, 2)
        ])

        for day in [utcDate(2026, 1, 3, 0), utcDate(2026, 1, 4, 0)] {
            let bucket = model.historyDays.first { $0.date == day }
            XCTAssertEqual(bucket?.peakMinutes, 0, "\(day) should have no peak minutes")
            XCTAssertEqual(bucket?.offPeakMinutes, 1440, "\(day) should be fully off-peak")
        }
    }

    func testBackfillOnLaunchWithEmptyStoreRecordsOnlyNow() {
        let store = HistoryStore(defaults: nil)
        let model = AppModel(
            settings: makeSettings(),
            config: .fallback,
            clock: Clock(now: utcDate(2026, 1, 5, 2)),
            history: store,
            autoStart: false
        )

        XCTAssertEqual(store.samples, [HistorySample(timestamp: utcDate(2026, 1, 5, 2), isPeak: true)])
        XCTAssertEqual(model.historyDays.count, 7)
        XCTAssertTrue(model.historyDays.last?.isCurrentDay ?? false)
    }

    func testTickCallbackRecordsHistory() {
        let clock = Clock(now: utcDate(2026, 1, 5, 2))
        let store = HistoryStore(defaults: nil)
        let model = AppModel(
            settings: makeSettings(),
            config: .fallback,
            clock: clock,
            history: store,
            autoStart: false
        )

        clock.onTick?(utcDate(2026, 1, 5, 5)) // transition from peak to off-peak

        XCTAssertEqual(store.samples.last?.isPeak, false)
        _ = model
    }

    func testHasHistoryReflectsStoredSamples() {
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: true, at: utcDate(2026, 1, 5, 1))
        let model = AppModel(
            settings: makeSettings(),
            config: .fallback,
            clock: Clock(now: utcDate(2026, 1, 5, 2)),
            history: store,
            autoStart: false
        )

        XCTAssertTrue(model.hasHistory)

        store.removeAll()
        model.refreshHistory()
        XCTAssertFalse(model.hasHistory)
    }

    func testClearHistoryEmptiesStoreAndChart() {
        let settings = makeSettings()
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: true, at: utcDate(2026, 1, 5, 1))
        let model = AppModel(
            settings: settings,
            config: .fallback,
            clock: Clock(now: utcDate(2026, 1, 5, 2)),
            history: store,
            autoStart: false
        )
        XCTAssertTrue(model.hasHistory)

        model.clearHistory()

        XCTAssertTrue(store.samples.isEmpty)
        XCTAssertFalse(model.hasHistory)
        XCTAssertEqual(model.historyDays.count, 7)
        XCTAssertTrue(model.historyDays.allSatisfy { $0.totalMinutes == 0 })

        settings.timeZoneIdentifier = "America/Los_Angeles"
        model.backfillHistory()
        XCTAssertEqual(model.historyDays.count, 7)
        XCTAssertTrue(model.historyDays.allSatisfy { $0.totalMinutes == 0 })
    }

    private func startOfDay(_ date: Date, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    func testTimeZoneChangeReaggregatesWithoutDuplicatingSamples() {
        let settings = makeSettings(timeZoneIdentifier: "UTC")
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: true, at: utcDate(2026, 1, 2, 8)) // Friday peak

        let model = AppModel(
            settings: settings, config: .fallback,
            clock: Clock(now: utcDate(2026, 1, 5, 2)), history: store, autoStart: false
        )
        let launchSamples = store.samples

        let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
        settings.timeZoneIdentifier = "America/Los_Angeles"
        model.backfillHistory()

        XCTAssertEqual(model.timeZone, losAngeles)
        XCTAssertEqual(store.samples, launchSamples, "Timezone change must not duplicate samples")
        XCTAssertEqual(model.historyDays.count, 7)
        XCTAssertEqual(model.historyDays.last?.date, startOfDay(utcDate(2026, 1, 5, 2), in: losAngeles))

        let saturday = startOfDay(utcDate(2026, 1, 3, 20), in: losAngeles)
        let bucket = model.historyDays.first { $0.date == saturday }
        XCTAssertEqual(bucket?.peakMinutes, 0)
        XCTAssertEqual(bucket?.offPeakMinutes, 1440)
    }

    func testTimeZoneChangeTwiceKeepsStoreStable() {
        let settings = makeSettings(timeZoneIdentifier: "UTC")
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: true, at: utcDate(2026, 1, 2, 8))
        let model = AppModel(
            settings: settings, config: .fallback,
            clock: Clock(now: utcDate(2026, 1, 5, 2)), history: store, autoStart: false
        )
        let launchSamples = store.samples

        settings.timeZoneIdentifier = "America/Los_Angeles"
        model.backfillHistory()
        settings.timeZoneIdentifier = "Asia/Kolkata"
        model.backfillHistory()
        settings.timeZoneIdentifier = "America/Los_Angeles"
        model.backfillHistory()

        XCTAssertEqual(store.samples, launchSamples, "Repeated timezone changes must be idempotent")
        XCTAssertEqual(model.historyDays.count, 7)
    }

    func testTimeZoneChangeToDSTZoneIsStable() {
        let settings = makeSettings(timeZoneIdentifier: "UTC")
        let store = HistoryStore(defaults: nil)
        store.record(isPeak: true, at: utcDate(2026, 1, 2, 8))
        let model = AppModel(
            settings: settings, config: .fallback,
            clock: Clock(now: utcDate(2026, 1, 5, 2)), history: store, autoStart: false
        )
        let launchSamples = store.samples

        settings.timeZoneIdentifier = "America/New_York"
        model.backfillHistory()

        XCTAssertEqual(store.samples, launchSamples)
        XCTAssertEqual(model.historyDays.count, 7)
        // The samples stay pruned to the 7-day window after reaggregation.
        XCTAssertLessThanOrEqual(model.historyDays.reduce(0) { $0 + $1.totalMinutes }, 7 * 1440)
    }

    func testLanguageChangeReschedulesNotifications() {
        let suite = "AppModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        settings.timeZoneIdentifier = "UTC"
        settings.notificationsEnabled = true
        settings.notifyOnOffPeakStart = true
        settings.notifyOnPeakStart = true

        let client = MockNotificationCenterClient()
        let model = AppModel(
            settings: settings,
            config: .fallback,
            clock: Clock(now: utcDate(2026, 1, 5, 22, 0)),
            notifications: NotificationManager(makeClient: { client }),
            autoStart: false
        )

        let before = client.removeAllCount
        let exp = expectation(description: "notifications rescheduled")

        NotificationCenter.default.post(
            name: Notification.Name(rawValue: LCLLanguageChangeNotification),
            object: nil
        )
        DispatchQueue.main.async { exp.fulfill() }

        wait(for: [exp], timeout: 1)
        XCTAssertGreaterThan(model.languageRevision, 0)
        XCTAssertGreaterThan(client.removeAllCount, before)
        XCTAssertFalse(client.addedRequests.isEmpty)
    }
}
