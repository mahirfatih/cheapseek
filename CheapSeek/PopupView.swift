import SwiftUI
import Localize_Swift

struct PopupView: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings
    @State private var showInfo = false

    var body: some View {
        Group {
            if showInfo {
                infoContent
            } else {
                statusContent
            }
        }
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
            }
            PricingInfoView(config: model.config, timeZone: model.timeZone)
        }
        .padding()
        .frame(width: 340)
        .background(.regularMaterial)
    }

    private var statusContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let (target, targetIsPeak) = PeakCalculator.nextTransition(from: now, schedule: model.config.schedule)
            let countdown = CountdownFormatter.string(from: target.timeIntervalSince(now))
            let targetStatus = PeakStatus(isPeak: targetIsPeak)

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("app_title".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                PeakStatusBadge(status: PeakStatus(isPeak: model.isPeak))

                HStack {
                    Text("now_label".localized())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(now, format: .dateTime.hour().minute().second())
                        .monospacedDigit()
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)

                HStack {
                    Text("timezone_label".localized())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(model.timeZone.identifier)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)

                Divider()

                Text("today_schedule".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(model.schedule.enumerated()), id: \.offset) { _, segment in
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
                    Text(targetStatus.title)
                        .foregroundStyle(targetStatus.color)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)

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
    }

    private func scheduleRow(_ segment: (start: Date, end: Date, isPeak: Bool)) -> some View {
        let status = PeakStatus(isPeak: segment.isPeak)
        return HStack {
            Text("\(segment.start.formatted(date: .omitted, time: .shortened)) – \(segment.end.formatted(date: .omitted, time: .shortened))")
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
