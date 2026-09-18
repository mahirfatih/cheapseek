import SwiftUI
import Localize_Swift

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let config: DeepSeekConfig
    let model: AppModel

    @State private var showInfo: Bool

    init(settings: AppSettings, config: DeepSeekConfig = .fallback, model: AppModel, showInfo: Bool = false) {
        self.settings = settings
        self.config = config
        self.model = model
        _showInfo = State(initialValue: showInfo)
    }

    var languages: [AppLanguage] {
        AppLanguage.allCases.sorted { $0.displayName < $1.displayName }
    }

    var locale: Locale {
        AppLanguage(rawValue: Localize.currentLanguage())?.locale ?? .current
    }

    var body: some View {
        let _ = model.languageRevision
        content
            .id(model.languageRevision)
    }

    var content: some View {
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
                Section {
                    Picker("language".localized(), selection: languageBinding) {
                        ForEach(languages) { language in
                            Text("\(language.flag) \(language.displayName)").tag(language.rawValue)
                        }
                    }
                    .accessibilityIdentifier("settings.language")

                    LabeledContent("timezone".localized()) {
                        TimeZonePicker(selection: $settings.timeZoneIdentifier, locale: locale)
                            .accessibilityIdentifier("settings.timezone")
                    }
                }

                Section {
                    Toggle("settings.notifications.enable".localized(), isOn: notificationsEnabledBinding)
                        .accessibilityIdentifier("settings.notifications")

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

                Section {
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
                        .accessibilityIdentifier("settings.refreshInterval")
                }
            }
            .formStyle(.grouped)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .frame(width: 440)
        .accessibilityIdentifier("settings.root")
        .sheet(isPresented: $showInfo) {
            SettingsPricingSheet(config: config, timeZone: settings.timeZone) {
                showInfo = false
            }
        }
        .onChange(of: settings.updateInterval) { _, newValue in
            handleUpdateIntervalChange(newValue)
        }
        .onChange(of: settings.timeZoneIdentifier) { _, _ in
            handleTimeZoneChange()
        }
        .onChange(of: settings.notifyOnOffPeakStart) { _, _ in
            handleNotifyOffPeakChange()
        }
        .onChange(of: settings.notifyOnPeakStart) { _, _ in
            handleNotifyPeakChange()
        }
        .onChange(of: settings.quietHoursEnabled) { _, _ in
            handleQuietHoursChange()
        }
        .onAppear {
            handleAppear()
        }
    }

    func handleUpdateIntervalChange(_ value: Double) { model.setUpdateInterval(value) }
    func handleTimeZoneChange() {
        model.refreshNotifications()
        model.backfillHistory()
    }
    func handleNotifyOffPeakChange() { model.refreshNotifications() }
    func handleNotifyPeakChange() { model.refreshNotifications() }
    func handleQuietHoursChange() { model.refreshNotifications() }
    func handleAppear() { model.notifications.refreshAuthorizationStatus() }

    var notificationsEnabledBinding: Binding<Bool> {
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

    var beforePeakBinding: Binding<Double> {
        Binding(
            get: { Double(settings.notifyBeforePeakMinutes) },
            set: { value in
                settings.notifyBeforePeakMinutes = Int(value.rounded())
                model.refreshNotifications()
            }
        )
    }

    var beforePeakValue: String {
        settings.notifyBeforePeakMinutes == 0
            ? "settings.notifications.before_peak_off".localized()
            : "settings.notifications.before_peak_value".localizedFormat(settings.notifyBeforePeakMinutes)
    }

    var quietStartBinding: Binding<Date> {
        Binding(
            get: { quietDate(fromMinutes: settings.quietHoursStart) },
            set: {
                settings.quietHoursStart = quietMinutes(from: $0)
                model.refreshNotifications()
            }
        )
    }

    var quietEndBinding: Binding<Date> {
        Binding(
            get: { quietDate(fromMinutes: settings.quietHoursEnd) },
            set: {
                settings.quietHoursEnd = quietMinutes(from: $0)
                model.refreshNotifications()
            }
        )
    }

    var quietCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = settings.timeZone
        return calendar
    }

    func quietDate(fromMinutes minutes: Int) -> Date {
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = minutes / 60
        components.minute = minutes % 60
        return quietCalendar.date(from: components) ?? Date()
    }

    func quietMinutes(from date: Date) -> Int {
        let components = quietCalendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static let notificationSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
    )!

    func openNotificationSettings() {
        NSWorkspace.shared.open(Self.notificationSettingsURL)
    }

    var languageBinding: Binding<String> {
        Binding(
            get: { Localize.currentLanguage() },
            set: { code in
                Localize.setCurrentLanguage(code)
            }
        )
    }

    var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { enabled in
                settings.setLaunchAtLogin(enabled)
            }
        )
    }
}

/// The pricing sheet shown from the Settings info button.
struct SettingsPricingSheet: View {
    let config: DeepSeekConfig
    let timeZone: TimeZone
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("pricing".localized())
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("close".localized())
                .accessibilityLabel("close".localized())
            }
            .padding([.horizontal, .top])

            PricingInfoView(config: config, timeZone: timeZone, scrollable: false)
        }
    }
}
