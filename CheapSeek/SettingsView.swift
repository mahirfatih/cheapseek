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

                Section {
                    Toggle("settings.notifications.enable".localized(), isOn: notificationsEnabledBinding)

                    if settings.notificationsEnabled && model.notifications.permissionDenied {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("settings.notifications.permission_hint".localized())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("settings.notifications.open_settings".localized()) {
                                openNotificationSettings()
                            }
                            .buttonStyle(.link)
                        }
                    }

                    if settings.notificationsEnabled {
                        Toggle("settings.notifications.offpeak_start".localized(), isOn: $settings.notifyOnOffPeakStart)
                        Toggle("settings.notifications.peak_start".localized(), isOn: $settings.notifyOnPeakStart)

                        HStack {
                            Text("settings.notifications.before_peak".localized())
                            Spacer()
                            Text(beforePeakValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: beforePeakBinding, in: 0...30, step: 5)
                    }

                    Toggle("settings.notifications.quiet_hours".localized(), isOn: $settings.quietHoursEnabled)
                    if settings.quietHoursEnabled {
                        DatePicker("settings.notifications.quiet_start".localized(), selection: quietStartBinding, displayedComponents: .hourAndMinute)
                        DatePicker("settings.notifications.quiet_end".localized(), selection: quietEndBinding, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("notifications".localized())
                }

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
        .onChange(of: settings.timeZoneIdentifier) { _, _ in
            model.refreshNotifications()
        }
        .onChange(of: settings.notifyOnOffPeakStart) { _, _ in
            model.refreshNotifications()
        }
        .onChange(of: settings.notifyOnPeakStart) { _, _ in
            model.refreshNotifications()
        }
        .onChange(of: settings.quietHoursEnabled) { _, _ in
            model.refreshNotifications()
        }
        .onAppear {
            model.notifications.refreshAuthorizationStatus()
        }
    }

    private var notificationsEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.notificationsEnabled },
            set: { enabled in
                settings.notificationsEnabled = enabled
                if enabled {
                    model.notifications.requestPermission()
                }
                model.refreshNotifications()
            }
        )
    }

    private var beforePeakBinding: Binding<Double> {
        Binding(
            get: { Double(settings.notifyBeforePeakMinutes) },
            set: { value in
                settings.notifyBeforePeakMinutes = Int(value.rounded())
                model.refreshNotifications()
            }
        )
    }

    private var beforePeakValue: String {
        settings.notifyBeforePeakMinutes == 0
            ? "settings.notifications.before_peak_off".localized()
            : "settings.notifications.before_peak_value".localizedFormat(settings.notifyBeforePeakMinutes)
    }

    private var quietStartBinding: Binding<Date> {
        Binding(
            get: { quietDate(fromMinutes: settings.quietHoursStart) },
            set: {
                settings.quietHoursStart = quietMinutes(from: $0)
                model.refreshNotifications()
            }
        )
    }

    private var quietEndBinding: Binding<Date> {
        Binding(
            get: { quietDate(fromMinutes: settings.quietHoursEnd) },
            set: {
                settings.quietHoursEnd = quietMinutes(from: $0)
                model.refreshNotifications()
            }
        )
    }

    private var quietCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        return calendar
    }

    private func quietDate(fromMinutes minutes: Int) -> Date {
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = minutes / 60
        components.minute = minutes % 60
        return quietCalendar.date(from: components) ?? Date()
    }

    private func quietMinutes(from date: Date) -> Int {
        let components = quietCalendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
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
