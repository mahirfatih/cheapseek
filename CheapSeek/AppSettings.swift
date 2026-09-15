import Foundation
import ServiceManagement
import Localize_Swift

final class AppSettings: ObservableObject {
    private enum Keys {
        static let timeZone = "settings.timeZone"
        static let notifications = "settings.notificationsEnabled"
        static let updateInterval = "settings.updateInterval"
    }

    static let systemTimeZoneIdentifier = ""

    @Published var timeZoneIdentifier: String {
        didSet {
            UserDefaults.standard.set(timeZoneIdentifier, forKey: Keys.timeZone)
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notifications)
        }
    }

    @Published var updateInterval: Double {
        didSet {
            UserDefaults.standard.set(updateInterval, forKey: Keys.updateInterval)
        }
    }

    @Published private(set) var launchAtLogin: Bool = false
    @Published private(set) var loginItemError: Bool = false

    private var languageObserver: NSObjectProtocol?

    var timeZone: TimeZone {
        if timeZoneIdentifier.isEmpty {
            return .current
        }
        return TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    init() {
        let defaults = UserDefaults.standard

        if let tz = defaults.string(forKey: Keys.timeZone) {
            timeZoneIdentifier = tz
        } else {
            timeZoneIdentifier = Self.systemTimeZoneIdentifier
        }

        notificationsEnabled = defaults.object(forKey: Keys.notifications) as? Bool ?? false

        let storedInterval = defaults.double(forKey: Keys.updateInterval)
        updateInterval = storedInterval > 0 ? storedInterval : 60

        refreshLaunchAtLogin()

        languageObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(LCLLanguageChangeNotification),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    deinit {
        if let languageObserver {
            NotificationCenter.default.removeObserver(languageObserver)
        }
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
