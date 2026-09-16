import SwiftUI
import Localize_Swift

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let config: DeepSeekConfig
    let model: AppModel

    @State private var showInfo = false

    init(settings: AppSettings, config: DeepSeekConfig = .fallback, model: AppModel) {
        self.settings = settings
        self.config = config
        self.model = model
    }

    private var languages: [AppLanguage] {
        AppLanguage.allCases.sorted { $0.displayName < $1.displayName }
    }

    private var timeZoneIdentifiers: [String] {
        TimeZone.knownTimeZoneIdentifiers.sorted()
    }

    var body: some View {
        let _ = model.languageRevision
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("settings".localized())
                    .font(.headline)
                Spacer()
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .help("info".localized())
                .accessibilityLabel("info".localized())
            }

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
                    .disabled(true)
                Text("notifications_soon".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("launch_at_login".localized(), isOn: launchAtLoginBinding)
                if settings.loginItemError {
                    Text("login_item_error".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("update_interval".localized())
                    Spacer()
                    Text("update_interval_value".localizedFormat(Int(settings.updateInterval.rounded())))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.updateInterval, in: AppSettings.updateIntervalRange, step: 10)
            }
        }
        .padding()
        .frame(width: 380)
        .sheet(isPresented: $showInfo) {
            VStack(spacing: 0) {
                HStack {
                    Text("pricing".localized())
                        .font(.headline)
                    Spacer()
                    Button {
                        showInfo = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("close".localized())
                    .accessibilityLabel("close".localized())
                }
                .padding([.horizontal, .top])

                PricingInfoView(config: config, timeZone: settings.timeZone, scrollable: false)
            }
        }
        .onChange(of: settings.updateInterval) { _, newValue in
            model.setUpdateInterval(newValue)
        }
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { Localize.currentLanguage() },
            set: { code in
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
    let settings = AppSettings()
    let model = AppModel(settings: settings, config: .fallback, autoStart: false)
    return SettingsView(settings: settings, config: .fallback, model: model)
        .preferredColorScheme(.light)
}

#Preview("Settings · Dark") {
    let settings = AppSettings()
    let model = AppModel(settings: settings, config: .fallback, autoStart: false)
    return SettingsView(settings: settings, config: .fallback, model: model)
        .preferredColorScheme(.dark)
}
#endif
