import SwiftUI
import Localize_Swift

/// Peak / off-peak presentation state with a non-color visual cue.
enum PeakStatus: Equatable {
    case peak
    case offPeak

    init(isPeak: Bool) {
        self = isPeak ? .peak : .offPeak
    }

    var title: String {
        switch self {
        case .peak: return "status_peak".localized()
        case .offPeak: return "status_offpeak".localized()
        }
    }

    var color: Color {
        switch self {
        case .peak: return .red
        case .offPeak: return .green
        }
    }

    var symbolName: String {
        switch self {
        case .peak: return "dollarsign.circle.fill"
        case .offPeak: return "dollarsign.circle"
        }
    }
}

/// Reusable peak/off-peak label used across the popup.
struct PeakStatusBadge: View {
    let status: PeakStatus
    var style: Font = .headline
    var bold: Bool = true

    var body: some View {
        Label(status.title, systemImage: status.symbolName)
            .font(style)
            .fontWeight(bold ? .bold : .regular)
            .foregroundStyle(status.color)
            .accessibilityLabel(status.title)
    }
}
