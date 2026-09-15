import SwiftUI
import Localize_Swift

struct PricingInfoView: View {
    let config: DeepSeekConfig
    let timeZone: TimeZone
    var scrollable: Bool = true

    var body: some View {
        if scrollable {
            ScrollView { content }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            legend
            Divider()
            Text("per_million_tokens".localized())
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(config.models, id: \.id) { model in
                modelCard(model)
            }
            Divider()
            links
        }
        .padding()
    }

    private var legend: some View {
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

    private func modelCard(_ model: ModelPricing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.name)
                    .font(.headline)
                Spacer()
            }
            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                Text("off_peak_label".localized())
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(width: 76, alignment: .trailing)
                Text("peak_label".localized())
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(width: 76, alignment: .trailing)
            }
            priceRow("input_cache_hit".localized(), model.inputCacheHit)
            priceRow("input_cache_miss".localized(), model.inputCacheMiss)
            priceRow("output_tokens".localized(), model.output)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func priceRow(_ label: String, _ price: Price) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(priceString(price.offPeak))
                .font(.subheadline)
                .foregroundStyle(.green)
                .monospacedDigit()
                .frame(width: 76, alignment: .trailing)
            Text(priceString(price.peak))
                .font(.subheadline)
                .foregroundStyle(.red)
                .monospacedDigit()
                .frame(width: 76, alignment: .trailing)
        }
    }

    private var links: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = URL(string: config.pricingURL) {
                Link("view_pricing_page".localized(), destination: url)
            }
            if let url = URL(string: config.docsURL) {
                Link("api_docs".localized(), destination: url)
            }
            HStack {
                Text("base_url".localized())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(config.baseURL)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
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
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        var components = utcCalendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = window.startHour
        components.minute = 0
        guard let start = utcCalendar.date(from: components) else { return "" }
        let end = start.addingTimeInterval(TimeInterval((window.endHour - window.startHour) * 3600))

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: start))–\(formatter.string(from: end))"
    }

    private func priceString(_ value: Double) -> String {
        let roundedToCents = (value * 100).rounded() / 100
        if abs(roundedToCents - value) < 0.0001 {
            return String(format: "$%.2f", value)
        }
        return String(format: "$%.3f", value)
    }
}
