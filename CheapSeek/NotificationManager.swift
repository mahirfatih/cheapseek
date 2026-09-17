import Foundation
import Observation
import UserNotifications
import Localize_Swift

/// Thin seam over the system notification center so scheduling can be tested.
protocol NotificationCenterClient: AnyObject {
    func requestAuthorization(completion: @escaping (Bool) -> Void)
    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void)
    func add(_ requests: [UNNotificationRequest])
    func removeAllPending()
}

/// Seam over the real `UNUserNotificationCenter` so the client wrapper can be
/// exercised with a fake center; only `SystemUserNotificationCenterAdapter`
/// touches the system API.
protocol UserNotificationCenterAdapter: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions, completion: @escaping (Bool) -> Void)
    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void)
    func add(_ request: UNNotificationRequest)
    func removeAllPending()
}

/// Wraps `UNUserNotificationCenter` for the running app.
final class SystemNotificationCenterClient: NotificationCenterClient {
    private let center: UserNotificationCenterAdapter

    init(center: UserNotificationCenterAdapter = SystemUserNotificationCenterAdapter()) {
        self.center = center
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound], completion: completion)
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.authorizationStatus(completion: completion)
    }

    func add(_ requests: [UNNotificationRequest]) {
        for request in requests {
            center.add(request)
        }
    }

    func removeAllPending() {
        center.removeAllPending()
    }
}

/// No-op client used outside the app (previews, unit tests, disabled manager).
final class DisabledNotificationCenterClient: NotificationCenterClient {
    func requestAuthorization(completion: @escaping (Bool) -> Void) { completion(false) }
    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) { completion(.notDetermined) }
    func add(_ requests: [UNNotificationRequest]) {}
    func removeAllPending() {}
}

/// Owns notification permission state and (re)schedules transition notifications.
@Observable
final class NotificationManager {

    private let makeClient: () -> NotificationCenterClient
    @ObservationIgnored private var client: NotificationCenterClient?

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init(makeClient: @escaping () -> NotificationCenterClient = { SystemNotificationCenterClient() }) {
        self.makeClient = makeClient
    }

    static let disabled = NotificationManager(makeClient: { DisabledNotificationCenterClient() })

    var permissionDenied: Bool { authorizationStatus == .denied }

    private var activeClient: NotificationCenterClient {
        if let client { return client }
        let created = makeClient()
        client = created
        return created
    }

    func requestPermission() {
        activeClient.requestAuthorization { [weak self] granted in
            DispatchQueue.main.async {
                self?.authorizationStatus = granted ? .authorized : .denied
            }
        }
    }

    func refreshAuthorizationStatus() {
        activeClient.authorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.authorizationStatus = status
                if status == .denied {
                    self.activeClient.removeAllPending()
                }
            }
        }
    }

    /// Cancels every pending notification and, when enabled and not denied,
    /// schedules the freshly planned horizon.
    func reschedule(now: Date, schedule: PeakSchedule, settings: AppSettings) {
        guard settings.notificationsEnabled, authorizationStatus != .denied else {
            activeClient.removeAllPending()
            return
        }

        let quietHours = NotificationPlanner.QuietHours(
            enabled: settings.quietHoursEnabled,
            startMinutes: settings.quietHoursStart,
            endMinutes: settings.quietHoursEnd
        )

        let plans = NotificationPlanner.plan(
            now: now,
            schedule: schedule,
            timeZone: settings.timeZone,
            beforePeakMinutes: settings.notifyBeforePeakMinutes,
            notifyOnOffPeakStart: settings.notifyOnOffPeakStart,
            notifyOnPeakStart: settings.notifyOnPeakStart,
            quietHours: quietHours
        )

        activeClient.removeAllPending()
        activeClient.add(plans.map { request(for: $0, now: now) })
    }

    private func request(for plan: PlannedNotification, now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = plan.titleKey.localized()
        content.body = plan.bodyKey.localizedBody(argument: plan.bodyArgument)
        content.sound = .default
        content.userInfo = ["kind": plan.kind.rawValue]

        let interval = max(1, plan.fireDate.timeIntervalSince(now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        return UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger)
    }
}

private extension String {
    func localizedBody(argument: Int?) -> String {
        guard let argument else { return localized() }
        return localizedFormat(argument)
    }
}
