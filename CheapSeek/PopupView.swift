import SwiftUI
import Localize_Swift

struct PopupView: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings
    @State private var showInfo = false
    @State private var showHistory = true

    var body: some View {
        let _ = model.languageRevision
        Group {
            if showInfo {
                infoContent
            } else {
                statusContent
            }
        }
        .id(model.languageRevision)
    }

    private var infoContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("pricing".localized())
                    .font(.headline)
                Spacer()
                Button {
                    showInfo = false
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .help("close".localized())
                .accessibilityLabel("close".localized())
            }
            PricingInfoView(config: model.config, timeZone: model.timeZone)
        }
        .padding()
        .frame(width: 340)
        .background(.regularMaterial)
    }

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                let (target, targetIsPeak) = PeakCalculator.nextTransition(from: now, schedule: model.config.schedule)
                let countdown = CountdownFormatter.string(from: target.timeIntervalSince(now))
                let targetStatus = PeakStatus(isPeak: targetIsPeak)
                let currentStatus = PeakStatus(isPeak: PeakCalculator.isPeak(at: now, schedule: model.config.schedule))
                let schedule = PeakCalculator.schedules(for: model.timeZone, referenceDate: now, schedule: model.config.schedule)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("app_title".localized())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    PeakStatusBadge(status: currentStatus)

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
                            .help(model.timeZone.identifier)
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
                }
            }

            Divider()

            historySection

            Divider()

            HStack {
                Button("settings".localized()) {
                    openSettings()
                    NSApp.activate()
                }
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                .help("info".localized())
                .accessibilityLabel("info".localized())
                Spacer()
                Button("quit".localized()) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding()
        .frame(width: 280)
        .background(.regularMaterial)
    }

    private var historySection: some View {
        DisclosureGroup(isExpanded: $showHistory) {
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
    }

    private var locale: Locale {
        AppLanguage(rawValue: Localize.currentLanguage())?.locale ?? .current
    }

    private var timeFormat: Date.FormatStyle {
        var format = Date.FormatStyle()
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
            .second(.twoDigits)
        format.timeZone = model.timeZone
        format.locale = locale
        return format
    }

    private var timeShortFormat: Date.FormatStyle {
        var format = Date.FormatStyle(date: .omitted, time: .shortened)
        format.timeZone = model.timeZone
        format.locale = locale
        return format
    }

    private var timeZoneName: String {
        model.timeZone.localizedName(for: .shortStandard, locale: locale)
            ?? model.timeZone.identifier
    }

    private func scheduleRow(_ segment: (start: Date, end: Date, isPeak: Bool)) -> some View {
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

#if DEBUG
private extension AppModel {
    static func preview(isPeak: Bool) -> AppModel {
        let settings = AppSettings()
        settings.timeZoneIdentifier = "UTC"

        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 5
        components.hour = isPeak ? 2 : 12
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let date = calendar.date(from: components) ?? Date()

        return AppModel(
            settings: settings,
            config: .fallback,
            clock: Clock(now: date),
            autoStart: false
        )
    }
}

#Preview("Peak · Light") {
    PopupView(model: .preview(isPeak: true))
        .preferredColorScheme(.light)
}

#Preview("Peak · Dark") {
    PopupView(model: .preview(isPeak: true))
        .preferredColorScheme(.dark)
}

#Preview("Off-Peak · Light") {
    PopupView(model: .preview(isPeak: false))
        .preferredColorScheme(.light)
}

#Preview("Off-Peak · Dark") {
    PopupView(model: .preview(isPeak: false))
        .preferredColorScheme(.dark)
}
#endif
