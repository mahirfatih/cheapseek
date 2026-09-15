import Foundation
import ServiceManagement
import Observation

@Observable
final class AppSettings {
    private enum Keys {
        static let timeZone = "settings.timeZone"
        static let notifications = "settings.notificationsEnabled"
        static let updateInterval = "settings.updateInterval"
    }

    static let systemTimeZoneIdentifier = ""
    static let defaultUpdateInterval: Double = 60
    static let updateIntervalRange: ClosedRange<Double> = 30...300

    var timeZoneIdentifier: String {
        didSet { defaults.set(timeZoneIdentifier, forKey: Keys.timeZone) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications) }
    }

    var updateInterval: Double {
        didSet { defaults.set(updateInterval, forKey: Keys.updateInterval) }
    }

    private(set) var launchAtLogin = false
    private(set) var loginItemError = false

    private let defaults: UserDefaults

    var timeZone: TimeZone {
        if timeZoneIdentifier.isEmpty { return .current }
        return TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        timeZoneIdentifier = defaults.string(forKey: Keys.timeZone) ?? Self.systemTimeZoneIdentifier
        notificationsEnabled = defaults.object(forKey: Keys.notifications) as? Bool ?? false

        let stored = defaults.double(forKey: Keys.updateInterval)
        updateInterval = stored > 0
            ? min(max(stored, Self.updateIntervalRange.lowerBound), Self.updateIntervalRange.upperBound)
            : Self.defaultUpdateInterval

        refreshLaunchAtLogin()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = false
        } catch {
            loginItemError = true
        }
        refreshLaunchAtLogin()
    }

    private func refreshLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLogin = (status == .enabled || status == .requiresApproval)
    }
}
