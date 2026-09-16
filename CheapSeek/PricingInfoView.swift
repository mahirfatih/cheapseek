import SwiftUI
import Localize_Swift

struct PricingInfoView: View {
    let config: DeepSeekConfig
    let timeZone: TimeZone
    var scrollable: Bool = true

    private var locale: Locale {
        AppLanguage(rawValue: Localize.currentLanguage())?.locale ?? .current
    }

    var body: some View {
        if scrollable {
            ScrollView { content }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            PricingLegend(config: config, timeZone: timeZone, locale: locale)
            Divider()
            Text("per_million_tokens".localized())
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(config.models, id: \.id) { model in
                PricingModelCard(model: model, locale: locale)
            }
            Divider()
            LinksSection(config: config)
        }
        .padding()
    }
}

private struct PricingLegend: View {
    let config: DeepSeekConfig
    let timeZone: TimeZone
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("peak_label".localized())
                    .bold()
                    .foregroundStyle(.red)
                Spacer()
                Text("full_price".localized())
                    .foregroundStyle(.secondary)
            }
            Text("peak_window".localizedFormat(windowsUTCString))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("off_peak_label".localized())
                    .bold()
                    .foregroundStyle(.green)
                Spacer()
                Text("half_price".localized())
                    .foregroundStyle(.secondary)
            }
            Text("off_peak_window".localized())
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("your_time".localizedFormat(windowsLocalString))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var windowsUTCString: String {
        config.peakWindows
            .map { String(format: "%02d:00–%02d:00", $0.startHour, $0.endHour) }
            .joined(separator: ", ")
    }

    private var windowsLocalString: String {
        config.peakWindows.map(windowText).joined(separator: ", ")
    }

    private func windowText(_ window: PeakWindow) -> String {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = .gmt
        var components = utcCalendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = window.startHour
        components.minute = 0
        // GMT never observes DST, so a fixed hour offset between start and end is exact.
        guard let start = utcCalendar.date(from: components) else {
            return fallbackWindowText(window)
        }
        let end = start.addingTimeInterval(TimeInterval((window.endHour - window.startHour) * 3600))

        var format = Date.FormatStyle()
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
        format.timeZone = timeZone
        format.locale = locale
        return "\(start.formatted(format))–\(end.formatted(format))"
    }

    private func fallbackWindowText(_ window: PeakWindow) -> String {
        String(format: "%02d:00–%02d:00", window.startHour, window.endHour)
    }
}

private struct PricingModelCard: View {
    let model: ModelPricing
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(model.name)
                .font(.headline)

            Grid(horizontalSpacing: Spacing.md, verticalSpacing: Spacing.xs) {
                GridRow {
                    Text("")
                    Text("off_peak_label".localized())
                        .foregroundStyle(.green)
                        .gridColumnAlignment(.trailing)
                    Text("peak_label".localized())
                        .foregroundStyle(.red)
                        .gridColumnAlignment(.trailing)
                }
                .font(.caption)

                GridRow {
                    Text("input_cache_hit".localized())
                    Text(price(model.inputCacheHit.offPeak)).foregroundStyle(.green)
                    Text(price(model.inputCacheHit.peak)).foregroundStyle(.red)
                }
                GridRow {
                    Text("input_cache_miss".localized())
                    Text(price(model.inputCacheMiss.offPeak)).foregroundStyle(.green)
                    Text(price(model.inputCacheMiss.peak)).foregroundStyle(.red)
                }
                GridRow {
                    Text("output_tokens".localized())
                    Text(price(model.output.offPeak)).foregroundStyle(.green)
                    Text(price(model.output.peak)).foregroundStyle(.red)
                }
            }
            .font(.subheadline)
            .monospacedDigit()
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func price(_ value: Double) -> String {
        value.formatted(
            .currency(code: "USD")
                .locale(locale)
                .precision(.fractionLength(2...3))
        )
    }
}

private struct LinksSection: View {
    let config: DeepSeekConfig

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if let url = URL(string: config.usageURL) {
                Link("api_usage".localized(), destination: url)
            }
            if let url = URL(string: config.pricingURL) {
                Link("pricing_page".localized(), destination: url)
            }
            if let url = URL(string: config.docsURL) {
                Link("api_docs".localized(), destination: url)
            }
        }
    }
}
