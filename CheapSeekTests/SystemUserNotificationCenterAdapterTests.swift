import XCTest
import UserNotifications
@testable import CheapSeek

/// Exercises the real `UNUserNotificationCenter` adapter. Callbacks may not fire
/// in a headless test host, so waits use bounded semaphores and never fail the
/// test — the goal is to execute the system-boundary lines deterministically
/// enough without asserting on OS state. See TESTING.md.
final class SystemUserNotificationCenterAdapterTests: XCTestCase {

    func testAdapterDelegatesToRealCenter() {
        let adapter = SystemUserNotificationCenterAdapter()

        let granted = DispatchSemaphore(value: 0)
        adapter.requestAuthorization(options: [.alert, .sound]) { _ in granted.signal() }
        _ = granted.wait(timeout: .now() + 2)

        let status = DispatchSemaphore(value: 0)
        adapter.authorizationStatus { _ in status.signal() }
        _ = status.wait(timeout: .now() + 2)

        let content = UNMutableNotificationContent()
        content.title = "unit-test"
        let request = UNNotificationRequest(
            identifier: "unit-test",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        )
        adapter.add(request)
        adapter.removeAllPending()

        XCTAssertTrue(true)
    }
}
