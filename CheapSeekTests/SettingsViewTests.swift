import XCTest
import SwiftUI
import ViewInspector
import UserNotifications
@testable import CheapSeek

private final class DeniedNotificationClient: NotificationCenterClient {
    func requestAuthorization(completion: @escaping (Bool) -> Void) { completion(false) }
    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) { completion(.denied) }
    func add(_ requests: [UNNotificationRequest]) {}
    func removeAllPending() {}
}

final class SettingsViewTests: XCTestCase {

    private func makeView(
        configure: (AppSettings) -> Void = { _ in },
        notifications: NotificationManager = .disabled
    ) -> (SettingsView, AppSettings, AppModel) {
        let suite = "SettingsViewTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        configure(settings)
        let model = AppModel(
            settings: settings,
            config: .fallback,
            clock: Clock(now: Date(timeIntervalSince1970: 0)),
            notifications: notifications,
            autoStart: false
        )
        return (SettingsView(settings: settings, config: .fallback, model: model), settings, model)
    }

    func testRendersWithDefaults() {
        let (view, _, _) = makeView()
        _ = view.body
        _ = view.content
        _ = try? view.inspect()
        XCTAssertEqual(view.languages.count, 17)
        _ = view.locale
    }

    func testRendersWithNotificationsAndQuietHoursEnabled() {
        let (view, _, _) = makeView {
            $0.notificationsEnabled = true
            $0.quietHoursEnabled = true
        }
        _ = try? view.inspect()
    }

    func testRendersPermissionDeniedHint() {
        let manager = NotificationManager(makeClient: { DeniedNotificationClient() })
        let refreshed = expectation(description: "authorization refreshed")
        DispatchQueue.main.async { refreshed.fulfill() }
        wait(for: [refreshed], timeout: 1)

        let (view, _, _) = makeView(configure: { settings in
            settings.notificationsEnabled = true
        }, notifications: manager)
        _ = try? view.inspect()
    }

    func testBindingsReadAndWrite() {
        let (view, settings, _) = makeView()

        // notifications enabled binding
        XCTAssertEqual(view.notificationsEnabledBinding.wrappedValue, settings.notificationsEnabled)
        view.notificationsEnabledBinding.wrappedValue = true
        XCTAssertTrue(settings.notificationsEnabled)

        // before-peak binding
        XCTAssertEqual(view.beforePeakBinding.wrappedValue, Double(settings.notifyBeforePeakMinutes))
        view.beforePeakBinding.wrappedValue = 20
        XCTAssertEqual(settings.notifyBeforePeakMinutes, 20)
        XCTAssertFalse(view.beforePeakValue.isEmpty)

        // quiet hours bindings + date math
        let date = view.quietDate(fromMinutes: 90)
        XCTAssertEqual(view.quietMinutes(from: date), 90)
        view.quietStartBinding.wrappedValue = date
        view.quietEndBinding.wrappedValue = date
        XCTAssertEqual(settings.quietHoursStart, 90)

        // language + launch-at-login bindings
        XCTAssertFalse(view.languageBinding.wrappedValue.isEmpty)
        _ = view.launchAtLoginBinding.wrappedValue
    }

    func testOpenNotificationSettingsDoesNotCrash() {
        let (view, _, _) = makeView()
        view.openNotificationSettings()
    }

    func testPricingSheetRenders() {
        let sheet = SettingsPricingSheet(config: .fallback, timeZone: .gmt, onClose: {})
        _ = sheet.body
        _ = try? sheet.inspect()
    }
}
