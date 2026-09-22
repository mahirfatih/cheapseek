import SwiftUI
import AppKit
import Localize_Swift

/// The About sheet: app icon, name, version, and Labrus contact links.
struct AboutView: View {
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("close".localized())
                .accessibilityLabel("close".localized())
            }

            Image(nsImage: Self.appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            Text(Self.appName)
                .font(.title2)
                .bold()

            Text("about.version".localizedFormat(Self.version))
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .accessibilityIdentifier("about.version")

            Divider()

            VStack(alignment: .leading, spacing: Spacing.sm) {
                LabeledLink(label: "about.website".localized(), text: "labrus.com",
                            url: Self.websiteURL)
                LabeledLink(label: "about.contact".localized(), text: "info@labrus.com",
                            url: Self.contactURL)
            }

            Divider()

            VStack(spacing: 2) {
                Text("about.copyright".localized())
                Text("Turkey/Istanbul")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(width: 280)
        .accessibilityIdentifier("about.root")
    }

    static let appName = "CheapSeek"
    static let websiteURL = URL(string: "https://labrus.com")!
    static let contactURL = URL(string: "mailto:info@labrus.com")!

    /// "1.0.0 (1)", read from the host bundle; falls back when unavailable.
    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    static var appIcon: NSImage {
        NSApplication.shared.applicationIconImage
            ?? NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)
            ?? NSImage()
    }
}

/// A left-aligned "Label  link" row.
private struct LabeledLink: View {
    let label: String
    let text: String
    let url: URL

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: Spacing.sm)
            Link(text, destination: url)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout)
    }
}
