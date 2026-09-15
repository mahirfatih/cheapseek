import SwiftUI
import Localize_Swift

struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let _ = model.languageRevision
        if model.isPeak {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(.red)
                .accessibilityLabel("status_peak".localized())
        } else {
            Text("coding")
                .foregroundStyle(.green)
                .font(.system(size: 12, design: .monospaced))
                .accessibilityLabel("status_offpeak".localized())
        }
    }
}
