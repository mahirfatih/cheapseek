import SwiftUI

@main
struct CheapSeekApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var status: AppModel

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _status = StateObject(wrappedValue: AppModel(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            PopupView(viewModel: status)
        } label: {
            if status.isPeak {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.red)
            } else {
                Text("coding")
                    .foregroundStyle(.green)
                    .font(.system(size: 12, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(settings: settings)
        }
    }
}
