import SwiftUI
import AppKit
import Foundation

/// No-op login item used in UI-test mode so tests never touch `SMAppService`.
private struct NoopLoginItemService: LoginItemService {
    func register() throws {}
    func unregister() throws {}
    var isEnabled: Bool { false }
}

@main
struct CheapSeekApp: App {
    @State private var settings: AppSettings
    @State private var model: AppModel

    /// Retains the UI-test windows (created outside the scene graph).
    private static var uiTestPopupWindow: NSWindow?
    private static var uiTestSettingsWindow: NSWindow?

    init() {
        // `-UITestMode 1` is UI-test-only: it disables real notification scheduling
        // and launch-at-login, and presents the popup in a plain window (a
        // menu-bar-only agent's MenuBarExtra popup cannot be opened programmatically).
        // Production behavior is identical when the flag is absent.
        let arguments = ProcessInfo.processInfo.arguments
        let isUITest = arguments.contains("-UITestMode")
        let showsSettingsWindow = arguments.contains("-UITestSettings")
        let loginItem: LoginItemService = isUITest ? NoopLoginItemService() : SystemLoginItemService()
        let settings = AppSettings(loginItem: loginItem)
        let config = DeepSeekConfig.load()
        let notifications = isUITest ? NotificationManager.disabled : NotificationManager()
        let model = AppModel(settings: settings, config: config, notifications: notifications, history: HistoryStore())
        _settings = State(initialValue: settings)
        _model = State(initialValue: model)

        if isUITest {
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                let host = NSHostingController(
                    rootView: PopupView(model: model, fixedNow: Self.uiTestFixedDate())
                )
                let window = NSWindow(contentViewController: host)
                window.title = "CheapSeek"
                window.setContentSize(NSSize(width: 300, height: 640))
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                Self.uiTestPopupWindow = window
            }
        }

        if showsSettingsWindow {
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                let host = NSHostingController(
                    rootView: SettingsView(settings: settings, config: config, model: model)
                )
                let window = NSWindow(contentViewController: host)
                window.title = "CheapSeek Settings"
                window.setContentSize(NSSize(width: 460, height: 780))
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                Self.uiTestSettingsWindow = window
            }
        }
    }

    /// A fixed Monday-02:00-UTC instant (inside a peak window) so UI assertions are
    /// deterministic regardless of the wall clock.
    private static func uiTestFixedDate() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 5
        components.hour = 2
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    var body: some Scene {
        MenuBarExtra {
            PopupHost(model: model)
        } label: {
            MenuBarLabel(model: model)
                .id(model.languageRevision)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings, config: model.config, model: model)
        }
    }
}
