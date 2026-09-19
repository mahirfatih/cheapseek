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

    /// Retains the UI-test Settings window (created outside the scene graph).
    private static var uiTestWindow: NSWindow?

    init() {
        // `-UITestMode 1` keeps UI runs deterministic: no real notification
        // scheduling and no launch-at-login registration.
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

        if showsSettingsWindow {
            // Menu-bar-only agents have no hittable menu bar, so show Settings in a
            // plain window for UI testing (test-only; never used in production).
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
                Self.uiTestWindow = window
            }
        }
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
