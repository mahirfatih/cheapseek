import Foundation
import UserNotifications

/// The only type that talks to the real `UNUserNotificationCenter`. It is a thin
/// system-boundary adapter and is excluded from unit-test coverage (see TESTING.md);
/// everything above it is exercised through `UserNotificationCenterAdapter` fakes.
final class SystemUserNotificationCenterAdapter: UserNotificationCenterAdapter {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization(options: UNAuthorizationOptions, completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: options) { granted, _ in
            completion(granted)
        }
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    func add(_ request: UNNotificationRequest) {
        center.add(request)
    }

    func removeAllPending() {
        center.removeAllPendingNotificationRequests()
    }
}
