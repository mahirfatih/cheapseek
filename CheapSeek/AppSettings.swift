import Foundation
import ServiceManagement
import Observation

/// Seam over `SMAppService` so launch-at-login can be tested without touching
/// the real login-item state.
protocol LoginItemService {
    func register() throws
    func unregister() throws
    var isEnabled: Bool { get }
}

struct SystemLoginItemService: LoginItemService {
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }

    var isEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }
}

@Observable
final class AppSettings {
    private enum Keys {
        static let timeZone = "settings.timeZone"
        static let notifications = "settings.notificationsEnabled"
        static let updateInterval = "settings.updateInterval"
        static let notifyBeforePeakMinutes = "settings.notifyBeforePeakMinutes"
        static let notifyOnOffPeakStart = "settings.notifyOnOffPeakStart"
        static let notifyOnPeakStart = "settings.notifyOnPeakStart"
        static let quietHoursEnabled = "settings.quietHoursEnabled"
        static let quietHoursStart = "settings.quietHoursStart"
        static let quietHoursEnd = "settings.quietHoursEnd"
    }

    static let systemTimeZoneIdentifier = ""
    static let defaultUpdateInterval: Double = 60
    static let updateIntervalRange: ClosedRange<Double> = 30...300
    static let defaultNotifyBeforePeakMinutes = 5
    static let notifyBeforePeakMinutesRange: ClosedRange<Int> = 0...60
    static let defaultQuietHoursStart = 23 * 60
    static let defaultQuietHoursEnd = 7 * 60

    var timeZoneIdentifier: String {
        didSet { defaults.set(timeZoneIdentifier, forKey: Keys.timeZone) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications) }
    }

    var updateInterval: Double {
        didSet { defaults.set(updateInterval, forKey: Keys.updateInterval) }
    }

    var notifyBeforePeakMinutes: Int {
        didSet {
            defaults.set(notifyBeforePeakMinutes, forKey: Keys.notifyBeforePeakMinutes)
        }
    }

    var notifyOnOffPeakStart: Bool {
        didSet { defaults.set(notifyOnOffPeakStart, forKey: Keys.notifyOnOffPeakStart) }
    }

    var notifyOnPeakStart: Bool {
        didSet { defaults.set(notifyOnPeakStart, forKey: Keys.notifyOnPeakStart) }
    }

    var quietHoursEnabled: Bool {
        didSet { defaults.set(quietHoursEnabled, forKey: Keys.quietHoursEnabled) }
    }

    var quietHoursStart: Int {
        didSet {
            defaults.set(Self.normalizedMinutes(quietHoursStart), forKey: Keys.quietHoursStart)
        }
    }

    var quietHoursEnd: Int {
        didSet {
            defaults.set(Self.normalizedMinutes(quietHoursEnd), forKey: Keys.quietHoursEnd)
        }
    }

    private(set) var launchAtLogin = false
    private(set) var loginItemError = false

    private let defaults: UserDefaults
    private let loginItem: LoginItemService

    var timeZone: TimeZone {
        if timeZoneIdentifier.isEmpty { return .current }
        return TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    init(defaults: UserDefaults = .standard, loginItem: LoginItemService = SystemLoginItemService()) {
        self.defaults = defaults
        self.loginItem = loginItem

        timeZoneIdentifier = defaults.string(forKey: Keys.timeZone) ?? Self.systemTimeZoneIdentifier
        notificationsEnabled = defaults.object(forKey: Keys.notifications) as? Bool ?? false

        let stored = defaults.double(forKey: Keys.updateInterval)
        updateInterval = stored > 0
            ? min(max(stored, Self.updateIntervalRange.lowerBound), Self.updateIntervalRange.upperBound)
            : Self.defaultUpdateInterval

        let storedBeforePeak = defaults.object(forKey: Keys.notifyBeforePeakMinutes) as? Int
            ?? Self.defaultNotifyBeforePeakMinutes
        notifyBeforePeakMinutes = min(max(storedBeforePeak, Self.notifyBeforePeakMinutesRange.lowerBound),
                                      Self.notifyBeforePeakMinutesRange.upperBound)
        notifyOnOffPeakStart = defaults.object(forKey: Keys.notifyOnOffPeakStart) as? Bool ?? true
        notifyOnPeakStart = defaults.object(forKey: Keys.notifyOnPeakStart) as? Bool ?? false
        quietHoursEnabled = defaults.object(forKey: Keys.quietHoursEnabled) as? Bool ?? false
        quietHoursStart = Self.normalizedMinutes(
            defaults.object(forKey: Keys.quietHoursStart) as? Int ?? Self.defaultQuietHoursStart
        )
        quietHoursEnd = Self.normalizedMinutes(
            defaults.object(forKey: Keys.quietHoursEnd) as? Int ?? Self.defaultQuietHoursEnd
        )

        refreshLaunchAtLogin()
    }

    static func normalizedMinutes(_ minutes: Int) -> Int {
        ((minutes % 1440) + 1440) % 1440
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try loginItem.register()
            } else {
                try loginItem.unregister()
            }
            loginItemError = false
        } catch {
            loginItemError = true
        }
        refreshLaunchAtLogin()
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = loginItem.isEnabled
    }
}
