import SwiftUI
import Localize_Swift

struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let _ = model.languageRevision
        let status = PeakStatus(isPeak: model.isPeak)
        HStack(spacing: 3) {
            Image(systemName: Self.symbolName(for: status))
            Text(Self.text(for: status))
                .font(.system(size: 12, design: .monospaced))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.title)
        .accessibilityIdentifier("menuBar.status")
    }

    static func text(for status: PeakStatus) -> String {
        switch status {
        case .peak: return "menu_bar.status.peak".localized()
        case .offPeak: return "menu_bar.status.cheap".localized()
        }
    }

    static func symbolName(for status: PeakStatus) -> String {
        switch status {
        case .peak: return "flame.fill"
        case .offPeak: return "leaf"
        }
    }
}
