import XCTest
import UserNotifications
@testable import CheapSeek

private final class MockNotificationCenterClient: NotificationCenterClient {
    var requestedAuthorization = false
    var authorizationResult = true
    var status: UNAuthorizationStatus = .authorized
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removeAllCount = 0

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        requestedAuthorization = true
        completion(authorizationResult)
    }

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

final class NotificationManagerTests: XCTestCase {

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components) ?? Date()
    }

    private func makeSettings(configure: (AppSettings) -> Void = { _ in }) -> AppSettings {
        let suite = "NotificationManagerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        settings.timeZoneIdentifier = "UTC"
        configure(settings)
        return settings
    }

    private func makeManager(_ client: MockNotificationCenterClient) -> NotificationManager {
        NotificationManager(makeClient: { client })
    }

    func testRescheduleCancelsThenAddsPlannedRequests() {
        let client = MockNotificationCenterClient()
        let manager = makeManager(client)
        let settings = makeSettings {
            $0.notificationsEnabled = true
            $0.notifyOnOffPeakStart = true
            $0.notifyBeforePeakMinutes = 5
        }

        manager.reschedule(now: utcDate(2026, 1, 5, 22), schedule: .deepseekDefault, settings: settings)

        XCTAssertEqual(client.removeAllCount, 1)
        XCTAssertFalse(client.addedRequests.isEmpty)
        XCTAssertTrue(client.addedRequests.allSatisfy { $0.content.title.isEmpty == false })
        XCTAssertTrue(client.addedRequests.contains { $0.identifier.hasPrefix("peakSoon-") })
        XCTAssertTrue(client.addedRequests.contains { $0.identifier.hasPrefix("offPeakStart-") })
        XCTAssertTrue(client.addedRequests.allSatisfy { $0.trigger is UNTimeIntervalNotificationTrigger })
    }

    func testRescheduleResetsPendingOnEachCall() {
        let client = MockNotificationCenterClient()
        let manager = makeManager(client)
        let settings = makeSettings {
            $0.notificationsEnabled = true
            $0.notifyOnOffPeakStart = true
            $0.notifyOnPeakStart = true
        }

        manager.reschedule(now: utcDate(2026, 1, 5, 22), schedule: .deepseekDefault, settings: settings)
        let firstBatch = client.addedRequests.count
        manager.reschedule(now: utcDate(2026, 1, 5, 23), schedule: .deepseekDefault, settings: settings)

        XCTAssertEqual(client.removeAllCount, 2)
        XCTAssertGreaterThan(firstBatch, 0)
        XCTAssertGreaterThan(client.addedRequests.count, firstBatch)
    }

    func testDisabledSettingsClearPendingWithoutAdding() {
        let client = MockNotificationCenterClient()
        let manager = makeManager(client)
        let settings = makeSettings { $0.notificationsEnabled = false }

        manager.reschedule(now: utcDate(2026, 1, 5, 22), schedule: .deepseekDefault, settings: settings)

        XCTAssertEqual(client.removeAllCount, 1)
        XCTAssertTrue(client.addedRequests.isEmpty)
    }

    func testDeniedPermissionSkipsScheduling() {
        let client = MockNotificationCenterClient()
        client.status = .denied
        let manager = makeManager(client)
        let settings = makeSettings {
            $0.notificationsEnabled = true
            $0.notifyOnOffPeakStart = true
        }

        let refreshed = expectation(description: "authorization refreshed")
        manager.refreshAuthorizationStatus()
        DispatchQueue.main.async { refreshed.fulfill() }
        wait(for: [refreshed], timeout: 1)

        XCTAssertTrue(manager.permissionDenied)
        manager.reschedule(now: utcDate(2026, 1, 5, 22), schedule: .deepseekDefault, settings: settings)
        XCTAssertTrue(client.addedRequests.isEmpty)
    }

    func testRequestPermissionUpdatesDeniedState() {
        let client = MockNotificationCenterClient()
        client.authorizationResult = false
        let manager = makeManager(client)

        let handled = expectation(description: "permission handled")
        manager.requestPermission()
        DispatchQueue.main.async { handled.fulfill() }
        wait(for: [handled], timeout: 1)

        XCTAssertTrue(client.requestedAuthorization)
        XCTAssertTrue(manager.permissionDenied)
    }

    func testSystemClientDelegatesToCenterAdapter() {
        let adapter = FakeUserNotificationCenterAdapter()
        let client = SystemNotificationCenterClient(center: adapter)

        let content = UNMutableNotificationContent()
        content.title = "x"
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: nil)

        client.requestAuthorization { _ in }
        client.authorizationStatus { _ in }
        client.add([request])
        client.removeAllPending()

        XCTAssertTrue(adapter.requestedAuthorization)
        XCTAssertEqual(adapter.added.count, 1)
        XCTAssertEqual(adapter.removeAllCount, 1)
    }

    func testDisabledClientMethodsAreNoOps() {
        let client = DisabledNotificationCenterClient()

        var granted: Bool?
        client.requestAuthorization { granted = $0 }
        var status: UNAuthorizationStatus?
        client.authorizationStatus { status = $0 }
        client.add([])
        client.removeAllPending()

        XCTAssertEqual(granted, false)
        XCTAssertEqual(status, .notDetermined)
    }
}

private final class FakeUserNotificationCenterAdapter: UserNotificationCenterAdapter {
    var requestedAuthorization = false
    var status: UNAuthorizationStatus = .authorized
    private(set) var added: [UNNotificationRequest] = []
    private(set) var removeAllCount = 0

    func requestAuthorization(options: UNAuthorizationOptions, completion: @escaping (Bool) -> Void) {
        requestedAuthorization = true
        completion(true)
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        completion(status)
    }

    func add(_ request: UNNotificationRequest) {
        added.append(request)
    }

    func removeAllPending() {
        removeAllCount += 1
    }
}
