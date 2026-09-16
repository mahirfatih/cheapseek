import SwiftUI

@main
struct CheapSeekApp: App {
    @State private var settings: AppSettings
    @State private var model: AppModel

    init() {
        let settings = AppSettings()
        let config = DeepSeekConfig.load()
        let model = AppModel(settings: settings, config: config, notifications: NotificationManager(), history: HistoryStore())
        _settings = State(initialValue: settings)
        _model = State(initialValue: model)
    }

    var body: some Scene {
        MenuBarExtra {
            PopupView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings, config: model.config, model: model)
        }
    }
}
