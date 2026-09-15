import SwiftUI
import Localize_Swift

struct PopupView: View {
    @ObservedObject var viewModel: AppModel

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let (target, targetIsPeak) = PeakCalculator.nextTransition(from: now)
            let countdown = CountdownFormatter.string(from: target.timeIntervalSince(now))

            VStack(alignment: .leading, spacing: 12) {
                Text("app_title".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text((viewModel.isPeak ? "status_peak" : "status_offpeak").localized())
                    .font(.headline)
                    .bold()
                    .foregroundStyle(viewModel.isPeak ? .red : .green)

                HStack {
                    Text("now_label".localized())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(now, format: .dateTime.hour().minute().second())
                        .monospacedDigit()
                }
                .font(.subheadline)

                HStack {
                    Text("timezone_label".localized())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.timeZone.identifier)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.subheadline)

                Divider()

                Text("today_schedule".localized())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(viewModel.schedule.enumerated()), id: \.offset) { _, segment in
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
                    Text((targetIsPeak ? "to_peak" : "to_offpeak").localized())
                        .foregroundStyle(targetIsPeak ? .red : .green)
                }
                .font(.subheadline)

                Divider()

                HStack {
                    Button("settings".localized()) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
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
        HStack {
            Text("\(segment.start.formatted(date: .omitted, time: .shortened)) – \(segment.end.formatted(date: .omitted, time: .shortened))")
                .monospacedDigit()
            Spacer()
            Text((segment.isPeak ? "status_peak" : "status_offpeak").localized())
                .font(.caption)
                .foregroundStyle(segment.isPeak ? .red : .green)
        }
        .font(.subheadline)
    }
}

#if DEBUG
private extension AppModel {
    static func preview(isPeak: Bool) -> AppModel {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 5
        components.hour = isPeak ? 2 : 12
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: components)!
        return AppModel(
            settings: AppSettings(),
            date: date,
            timeZone: TimeZone(identifier: "UTC")!,
            autoRefresh: false
        )
    }
}

#Preview("Peak · Light") {
    PopupView(viewModel: .preview(isPeak: true))
        .preferredColorScheme(.light)
}

#Preview("Peak · Dark") {
    PopupView(viewModel: .preview(isPeak: true))
        .preferredColorScheme(.dark)
}

#Preview("Off-Peak · Light") {
    PopupView(viewModel: .preview(isPeak: false))
        .preferredColorScheme(.light)
}

#Preview("Off-Peak · Dark") {
    PopupView(viewModel: .preview(isPeak: false))
        .preferredColorScheme(.dark)
}
#endif
