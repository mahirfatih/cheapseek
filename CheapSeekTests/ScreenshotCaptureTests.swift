import XCTest
import SwiftUI
import AppKit
@testable import CheapSeek

/// Renders the main screens offscreen with SwiftUI's `ImageRenderer` and writes
/// light/dark PNGs for the gallery in `docs/screenshots/`.
///
/// macOS has no simulator, so the screenshots are produced from the real views
/// rather than a running app. The test is **skipped** unless the runner is
/// invoked with `TEST_RUNNER_CAPTURE_SCREENSHOTS=1` (see
/// `test/capture-screenshots.sh`), so the normal unit run never writes files.
/// Output goes to the directory in `SCREENSHOT_OUT_DIR`, split into `light/`
/// and `dark/` subdirectories.
@MainActor
final class ScreenshotCaptureTests: XCTestCase {

    private func utcDate(_ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour)) ?? Date()
    }

    private func makeSettings(configure: (AppSettings) -> Void = { _ in }) -> AppSettings {
        let suite = "ScreenshotCaptureTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        settings.timeZoneIdentifier = "America/Los_Angeles"
        configure(settings)
        return settings
    }

    private func makeModel(now: Date = Date(timeIntervalSince1970: 0)) -> AppModel {
        AppModel(
            settings: makeSettings(),
            config: .fallback,
            clock: Clock(now: now),
            notifications: .disabled,
            autoStart: false
        )
    }

    /// Rasterizes `view` at the given size and writes it under
    /// `directory/<light|dark>/<name>.png`.
    private func capture(
        _ name: String,
        _ view: some View,
        size: CGSize,
        scheme: ColorScheme,
        to directory: URL
    ) throws {
        let content = view
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2

        guard let cgImage = renderer.cgImage else {
            throw XCTSkip("ImageRenderer could not rasterize \(name) (\(scheme))")
        }
        let representation = NSBitmapImageRep(cgImage: cgImage)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw XCTSkip("Could not encode \(name) (\(scheme)) as PNG")
        }

        let mode = scheme == .dark ? "dark" : "light"
        let outputDirectory = directory.appendingPathComponent(mode, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try data.write(to: outputDirectory.appendingPathComponent("\(name).png"))
    }

    private func captureScreens(scheme: ColorScheme, to directory: URL) throws {
        let now = utcDate(5, 2)
        let size = CGSize(width: 300, height: 600)

        try capture(
            "popup",
            PopupView(model: makeModel(now: now)),
            size: size,
            scheme: scheme,
            to: directory
        )

        try capture(
            "pricing",
            PricingInfoView(config: .fallback, timeZone: .gmt),
            size: size,
            scheme: scheme,
            to: directory
        )

        try capture(
            "settings",
            SettingsView(settings: makeSettings(), config: .fallback, model: makeModel(now: now)),
            size: CGSize(width: 460, height: 560),
            scheme: scheme,
            to: directory
        )

        try capture(
            "timezone-picker",
            TimeZonePicker(selection: .constant("America/Los_Angeles"), locale: Locale(identifier: "en_US")),
            size: size,
            scheme: scheme,
            to: directory
        )
    }

    func testCaptureScreenshots() throws {
        let environment = ProcessInfo.processInfo.environment
        let enabled = environment["TEST_RUNNER_CAPTURE_SCREENSHOTS"] == "1"
            || environment["CAPTURE_SCREENSHOTS"] == "1"
        try XCTSkipUnless(enabled, "Set TEST_RUNNER_CAPTURE_SCREENSHOTS=1 to capture screenshots")

        guard let outputPath = environment["SCREENSHOT_OUT_DIR"]
            ?? environment["TEST_RUNNER_SCREENSHOT_OUT_DIR"] else {
            throw XCTSkip("Set SCREENSHOT_OUT_DIR to a writable directory")
        }

        let outputDirectory = URL(fileURLWithPath: outputPath, isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        for scheme in [ColorScheme.light, .dark] {
            try captureScreens(scheme: scheme, to: outputDirectory)
        }
    }
}
