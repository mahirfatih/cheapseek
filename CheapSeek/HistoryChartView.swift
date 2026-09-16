import SwiftUI
import Charts
import Localize_Swift

/// Stacked bar chart of the last N days: green = off-peak, red = peak.
struct HistoryChartView: View {
    let days: [DayDistribution]
    let timeZone: TimeZone

    private var hasData: Bool { days.contains { $0.totalMinutes > 0 } }

    var body: some View {
        if hasData {
            chart
        } else {
            Text("history.empty".localized())
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var offPeakLabel: String { "history.offpeak".localized() }
    private var peakLabel: String { "history.peak".localized() }

    private var chart: some View {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("history.title".localized(), day.date, unit: .day),
                    y: .value("unit_minutes".localized(), day.offPeakMinutes)
                )
                .foregroundStyle(by: .value("Status", offPeakLabel))

                BarMark(
                    x: .value("history.title".localized(), day.date, unit: .day),
                    y: .value("unit_minutes".localized(), day.peakMinutes)
                )
                .foregroundStyle(by: .value("Status", peakLabel))
            }
        }
        .chartForegroundStyleScale(domain: [offPeakLabel, peakLabel], range: [Color.green, Color.red])
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                AxisValueLabel(format: weekdayFormat)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))")
                    }
                }
            }
        }
        .chartLegend(position: .bottom, alignment: .leading, spacing: 4)
        .frame(height: 120)
        .accessibilityLabel("history.last7days".localized())
    }

    private var locale: Locale {
        AppLanguage(rawValue: Localize.currentLanguage())?.locale ?? .current
    }

    private var weekdayFormat: Date.FormatStyle {
        var format = Date.FormatStyle().weekday(.narrow)
        format.locale = locale
        format.timeZone = timeZone
        return format
    }
}
