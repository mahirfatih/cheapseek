import SwiftUI
import Localize_Swift

/// Reads the `openSettings` environment action and hands it to `PopupView`, so
/// the popup itself stays free of environment dependencies and testable.
struct PopupHost: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        PopupView(
            model: model,
            onOpenSettings: {
                openSettings()
                NSApp.activate()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
    }
}

struct PopupView: View {
    let model: AppModel
    var onOpenSettings: () -> Void
    var onQuit: () -> Void
    @State private var showInfo: Bool
    @State private var showHistory: Bool

    init(
        model: AppModel,
        showInfo: Bool = false,
        showHistory: Bool = true,
        onOpenSettings: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.model = model
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        _showInfo = State(initialValue: showInfo)
        _showHistory = State(initialValue: showHistory)
    }

    var body: some View {
        let _ = model.languageRevision
        Group {
            if showInfo {
                PopupInfoContent(config: model.config, timeZone: model.timeZone) {
                    showInfo = false
                }
            } else {
                statusContent
            }
        }
        .id(model.languageRevision)
        .accessibilityIdentifier("popup.root")
    }

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                PopupStatusBody(model: model, now: context.date)
            }

            Divider()

            PopupHistorySection(model: model, isExpanded: $showHistory)

            Divider()

            PopupActionButtons(
                onSettings: onOpenSettings,
                onInfo: {
                    showInfo = true
                },
                onQuit: onQuit
            )
        }
        .padding()
        .frame(width: 280)
        .background(.regularMaterial)
    }
}

/// The per-tick status block, extracted so it can be inspected with a fixed date.
struct PopupStatusBody: View {
    let model: AppModel
    let now: Date

    var body: some View {
        let (target, targetIsPeak) = PeakCalculator.nextTransition(from: now, schedule: model.config.schedule)
        let countdown = CountdownFormatter.string(from: target.timeIntervalSince(now))
        let targetStatus = PeakStatus(isPeak: targetIsPeak)
        let currentStatus = PeakStatus(isPeak: PeakCalculator.isPeak(at: now, schedule: model.config.schedule))
        let schedule = PeakCalculator.schedules(for: model.timeZone, referenceDate: now, schedule: model.config.schedule)

        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("app_title".localized())
                .font(.caption)
                .foregroundStyle(.secondary)

            PeakStatusBadge(status: currentStatus)
                .accessibilityIdentifier("popup.status")

            HStack {
                Text("now_label".localized())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(now, format: timeFormat)
                    .monospacedDigit()
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)

            HStack {
                Text("timezone_label".localized())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(timeZoneName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(TimeZoneLabel.displayName(for: model.timeZone))
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)

            Divider()

            Text("today_schedule".localized())
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(schedule.enumerated()), id: \.offset) { _, segment in
                scheduleRow(segment)
            }

            Divider()

            HStack {
                Text("next_change".localized())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("in_label".localized())
                Text(countdown)
                    .bold()
                    .monospacedDigit()
                Text(targetIsPeak ? "to_peak".localized() : "to_offpeak".localized())
                    .foregroundStyle(targetStatus.color)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("popup.countdown")
        }
    }

    var locale: Locale {
        AppLanguage(rawValue: Localize.currentLanguage())?.locale ?? .current
    }

    var timeFormat: Date.FormatStyle {
        var format = Date.FormatStyle()
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
            .second(.twoDigits)
        format.timeZone = model.timeZone
        format.locale = locale
        return format
    }

    var timeShortFormat: Date.FormatStyle {
        var format = Date.FormatStyle(date: .omitted, time: .shortened)
        format.timeZone = model.timeZone
        format.locale = locale
        return format
    }

    var timeZoneName: String {
        TimeZoneLabel.string(for: model.timeZone)
    }

    func scheduleRow(_ segment: (start: Date, end: Date, isPeak: Bool)) -> some View {
        let status = PeakStatus(isPeak: segment.isPeak)
        return HStack {
            Text("\(segment.start.formatted(timeShortFormat)) – \(segment.end.formatted(timeShortFormat))")
                .monospacedDigit()
            Spacer()
            Text(status.title)
                .font(.caption)
                .foregroundStyle(status.color)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

/// The pricing/info page shown when the info button is tapped.
struct PopupInfoContent: View {
    let config: DeepSeekConfig
    let timeZone: TimeZone
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("pricing".localized())
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .help("close".localized())
                .accessibilityLabel("close".localized())
            }
            PricingInfoView(config: config, timeZone: timeZone)
        }
        .padding()
        .frame(width: 340)
        .background(.regularMaterial)
    }
}

/// The collapsible history chart.
struct PopupHistorySection: View {
    let model: AppModel
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            HistoryChartView(days: model.historyDays, timeZone: model.timeZone)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("history.title".localized())
                    .font(.subheadline)
                Text("history.last7days".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("popup.history.toggle")
    }
}

/// The footer action buttons.
struct PopupActionButtons: View {
    let onSettings: () -> Void
    let onInfo: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack {
            Button("settings".localized(), action: onSettings)
            Button(action: onInfo) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
            .help("info".localized())
            .accessibilityLabel("info".localized())
            Spacer()
            Button("quit".localized(), action: onQuit)
        }
    }
}
