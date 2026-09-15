import SwiftUI
import Localize_Swift

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let config: DeepSeekConfig

    @State private var selectedLanguage: String = Localize.currentLanguage()

    init(settings: AppSettings, config: DeepSeekConfig = .fallback) {
        self.settings = settings
        self.config = config
    }

    private var languages: [AppLanguage] {
        AppLanguage.allCases.sorted { $0.displayName < $1.displayName }
    }

    private var timeZoneIdentifiers: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }

    var body: some View {
        Form {
            Picker("language".localized(), selection: languageBinding) {
                ForEach(languages) { language in
                    Text("\(language.flag) \(language.displayName)").tag(language.rawValue)
                }
            }

            Picker("timezone".localized(), selection: $settings.timeZoneIdentifier) {
                Text("system_timezone".localized()).tag(AppSettings.systemTimeZoneIdentifier)
                ForEach(timeZoneIdentifiers, id: \.self) { identifier in
                    Text(identifier).tag(identifier)
                }
            }

            Toggle("notifications".localized(), isOn: $settings.notificationsEnabled)

            Toggle("launch_at_login".localized(), isOn: launchAtLoginBinding)
            if settings.loginItemError {
                Text("login_item_error".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("update_interval".localized())
                Spacer()
                Text("update_interval_value".localizedFormat(Int(settings.updateInterval)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.updateInterval, in: 30...300, step: 10)
        }
        .padding()
        .frame(width: 360)
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { selectedLanguage },
            set: { code in
                selectedLanguage = code
                Localize.setCurrentLanguage(code)
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { enabled in
                settings.setLaunchAtLogin(enabled)
            }
        )
    }
}

#if DEBUG
#Preview("Settings · Light") {
    SettingsView(settings: AppSettings())
        .preferredColorScheme(.light)
}

#Preview("Settings · Dark") {
    SettingsView(settings: AppSettings())
        .preferredColorScheme(.dark)
}
#endif
