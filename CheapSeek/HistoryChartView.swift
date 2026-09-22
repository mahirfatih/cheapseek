import SwiftUI
import Charts
import Localize_Swift

/// Stacked bar chart of the last N days: green = off-peak, red = peak.
struct HistoryChartView: View {
    let days: [DayDistribution]
    let timeZone: TimeZone

    var hasData: Bool { days.contains { $0.totalMinutes > 0 } }

    var body: some View {
        if hasData {
            chart
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("popup.history.chart")
        } else {
            Text("history.empty".localized())
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("popup.history.chart")
        }
    }

    var offPeakLabel: String { "history.offpeak".localized() }
    var peakLabel: String { "history.peak".localized() }

    private let daySeries = "history.day.series"
    private let statusSeries = "history.status.series"

    /// The in-progress bucket, exposed for tests. Production always uses the
    /// aggregator's last bucket; chart annotations are keyed from this value.
    var currentDay: DayDistribution? {
        days.last(where: \.isCurrentDay)
    }

    private var chart: some View {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value(daySeries, day.date, unit: .day),
                    y: .value("percent", day.offPeakShare)
                )
                .foregroundStyle(by: .value(statusSeries, offPeakLabel))
                .opacity(day.isCurrentDay ? 0.55 : 1)

                BarMark(
                    x: .value(daySeries, day.date, unit: .day),
                    y: .value("percent", day.peakShare)
                )
                .foregroundStyle(by: .value(statusSeries, peakLabel))
                .opacity(day.isCurrentDay ? 0.75 : 1)
            }

            if let currentDay {
                RuleMark(x: .value(daySeries, currentDay.date, unit: .day))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .accessibilityLabel(Text("now_label".localized()))
            }
        }
        .chartForegroundStyleScale(domain: [offPeakLabel, peakLabel], range: [.green.opacity(0.55), .red])
        .chartYScale(domain: 0...1)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: weekdayFormat)
                            .bold(isCurrentDay(date))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 0.25, 0.5, 0.75, 1]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let share = value.as(Double.self) {
                        Text("\(Int((share * 100).rounded()))%")
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 4)
        .environment(\.calendar, calendar)
        .environment(\.timeZone, timeZone)
        .frame(width: 200, height: 120)
        .accessibilityLabel("history.last7days".localized())
    }

    private func isCurrentDay(_ date: Date) -> Bool {
        guard let currentDay else { return false }
        return calendar.isDate(date, inSameDayAs: currentDay.date)
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    var locale: Locale {
        AppLanguage(rawValue: Localize.currentLanguage())?.locale ?? .current
    }

    var weekdayFormat: Date.FormatStyle {
        var format = Date.FormatStyle().weekday(.narrow)
        format.locale = locale
        format.timeZone = timeZone
        return format
    }
}
