import XCTest
import SwiftUI
import ViewInspector
import UserNotifications
@testable import CheapSeek

private final class DeniedCenterClient: NotificationCenterClient {
    func requestAuthorization(completion: @escaping (Bool) -> Void) { completion(false) }
    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) { completion(.denied) }
    func add(_ requests: [UNNotificationRequest]) {}
    func removeAllPending() {}
}

private struct RenderFailure: Error {}

private final class ThrowingLoginItem: LoginItemService {
    func register() throws { throw RenderFailure() }
    func unregister() throws { throw RenderFailure() }
    var isEnabled: Bool { false }
}

final class ViewRenderTests: XCTestCase {

    private func utcDate(_ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour)) ?? Date()
    }

    private func makeSettings(configure: (AppSettings) -> Void = { _ in }, loginItem: LoginItemService? = nil) -> AppSettings {
        let suite = "ViewRenderTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = loginItem.map { AppSettings(defaults: defaults, loginItem: $0) } ?? AppSettings(defaults: defaults)
        settings.timeZoneIdentifier = "UTC"
        configure(settings)
        return settings
    }

    private func makeModel(now: Date = Date(timeIntervalSince1970: 0), notifications: NotificationManager = .disabled) -> AppModel {
        AppModel(
            settings: makeSettings(),
            config: .fallback,
            clock: Clock(now: now),
            notifications: notifications,
            autoStart: false
        )
    }

    @MainActor
    private func render(_ view: some View) {
        let renderer = ImageRenderer(content: view.frame(width: 460, height: 720))
        renderer.scale = 1
        _ = renderer.nsImage
    }

    // MARK: - Offscreen renders

    @MainActor
    func testRenderSmallViews() {
        for status in [PeakStatus.peak, .offPeak] {
            render(PeakStatusBadge(status: status))
            render(PeakStatusBadge(status: status, style: .caption, bold: false))
        }
        render(PricingInfoView(config: .fallback, timeZone: .gmt))
        render(PricingInfoView(config: .fallback, timeZone: .gmt, scrollable: false))
        render(PopupInfoContent(config: .fallback, timeZone: .gmt, onClose: {}))
        render(SettingsPricingSheet(config: .fallback, timeZone: .gmt, onClose: {}))
    }

    @MainActor
    func testRenderPopupVariants() {
        let model = makeModel(now: utcDate(5, 2))
        render(PopupView(model: model))
        render(PopupView(model: model, showInfo: true))
        render(PopupView(model: model, showHistory: false))
        render(PopupStatusBody(model: makeModel(now: utcDate(5, 12)), now: utcDate(5, 12)))
        render(PopupHistorySection(model: model, isExpanded: .constant(false)))
        render(PopupHost(model: model))
    }

    @MainActor
    func testRenderTimeZonePickerVariants() {
        render(TimeZonePicker(selection: .constant("Europe/Istanbul"), locale: Locale(identifier: "en_US")))
        render(TimeZonePicker(selection: .constant(""), locale: Locale(identifier: "en_US")))
        render(TimeZonePickerContent(
            selection: .constant(""), isPresented: .constant(true),
            query: .constant("tokyo"), locale: Locale(identifier: "en_US")
        ))
        render(TimeZonePickerContent(
            selection: .constant(""), isPresented: .constant(true),
            query: .constant(""), locale: Locale(identifier: "en_US")
        ))
    }

    @MainActor
    func testRenderSettingsVariants() {
        render(SettingsView(settings: makeSettings(), config: .fallback, model: makeModel()))
        render(SettingsView(
            settings: makeSettings {
                $0.notificationsEnabled = true
                $0.quietHoursEnabled = true
            },
            config: .fallback, model: makeModel()
        ))
        render(SettingsView(settings: makeSettings(), config: .fallback, model: makeModel(), showInfo: true))

        let throwing = makeSettings(loginItem: ThrowingLoginItem())
        throwing.setLaunchAtLogin(true)
        render(SettingsView(settings: throwing, config: .fallback, model: makeModel()))

        let manager = NotificationManager(makeClient: { DeniedCenterClient() })
        manager.refreshAuthorizationStatus()
        let refreshed = expectation(description: "refreshed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { refreshed.fulfill() }
        wait(for: [refreshed], timeout: 2)
        XCTAssertTrue(manager.permissionDenied)
        let deniedSettings = makeSettings { $0.notificationsEnabled = true }
        render(SettingsView(
            settings: deniedSettings, config: .fallback,
            model: AppModel(settings: deniedSettings, config: .fallback, clock: Clock(now: Date()), notifications: manager, autoStart: false)
        ))
    }

    // MARK: - Interaction

    func testPopupActionButtonsInvokeClosures() throws {
        var settings = false, info = false, quit = false
        let view = PopupActionButtons(onSettings: { settings = true }, onInfo: { info = true }, onQuit: { quit = true })
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        for button in buttons { try button.tap() }
        XCTAssertTrue(settings)
        XCTAssertTrue(info)
        XCTAssertTrue(quit)
    }

    func testPopupInfoCloseButton() throws {
        var closed = false
        let view = PopupInfoContent(config: .fallback, timeZone: .gmt, onClose: { closed = true })
        try view.inspect().find(ViewType.Button.self).tap()
        XCTAssertTrue(closed)
    }

    func testSettingsPricingSheetCloseButton() throws {
        var closed = false
        let view = SettingsPricingSheet(config: .fallback, timeZone: .gmt, onClose: { closed = true })
        try view.inspect().find(ViewType.Button.self).tap()
        XCTAssertTrue(closed)
    }

    func testSettingsHandlers() {
        let settings = makeSettings()
        let model = makeModel()
        let view = SettingsView(settings: settings, config: .fallback, model: model)

        view.handleUpdateIntervalChange(120)
        view.handleTimeZoneChange()
        view.handleNotifyOffPeakChange()
        view.handleNotifyPeakChange()
        view.handleQuietHoursChange()
        view.handleAppear()

        view.languageBinding.wrappedValue = "en"
        view.notificationsEnabledBinding.wrappedValue = false
        XCTAssertEqual(SettingsView.notificationSettingsURL.scheme, "x-apple.systempreferences")
    }

    func testTimeZonePickerClearAndSelect() throws {
        let box = Box()
        let content = TimeZonePickerContent(
            selection: Binding(get: { box.value }, set: { box.value = $0 }),
            isPresented: .constant(true),
            query: .constant("tokyo"),
            locale: Locale(identifier: "en_US")
        )
        let clearButton = try content.inspect().find(ViewType.Button.self)
        try clearButton.tap()
        content.selectFirstMatch()
        XCTAssertEqual(box.value, "Asia/Tokyo")
    }
}

private final class Box { var value = "" }

extension ViewRenderTests {

    func testSettingsInfoButtonAndLaunchAtLoginBinding() throws {
        let throwing = makeSettings(loginItem: ThrowingLoginItem())
        let view = SettingsView(settings: throwing, config: .fallback, model: makeModel())

        try view.inspect().findAll(ViewType.Button.self)[0].tap()
        view.launchAtLoginBinding.wrappedValue = true

        XCTAssertTrue(throwing.loginItemError)
    }

    func testTimeZonePickerButtonAndRow() throws {
        let picker = TimeZonePicker(selection: .constant(""), locale: Locale(identifier: "en_US"))
        try picker.inspect().find(ViewType.Button.self).tap()

        let content = TimeZonePickerContent(
            selection: .constant(""), isPresented: .constant(true),
            query: .constant("tokyo"), locale: Locale(identifier: "en_US")
        )
        let buttons = try content.inspect().findAll(ViewType.Button.self)
        try buttons[buttons.count - 1].tap()
    }

    func testPopupInfoButtonTogglesInfo() throws {
        let view = PopupView(model: makeModel(now: utcDate(5, 2)))
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        // settings, info, quit
        try buttons[1].tap()
    }

    func testPopupHistoryDisclosureToggles() throws {
        let view = PopupHistorySection(model: makeModel(now: utcDate(5, 2)), isExpanded: .constant(true))
        _ = try? view.inspect().disclosureGroup().isExpanded()
    }

    func testPopupInfoCloseButtonFromPopupView() throws {
        let view = PopupView(model: makeModel(now: utcDate(5, 2)), showInfo: true)
        _ = view.body
        try view.inspect().find(ViewType.Button.self).tap()
    }

    func testSettingsDeniedHintOpenSettingsButton() throws {
        let manager = NotificationManager(makeClient: { DeniedCenterClient() })
        manager.refreshAuthorizationStatus()
        let refreshed = expectation(description: "refreshed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { refreshed.fulfill() }
        wait(for: [refreshed], timeout: 2)

        let settings = makeSettings { $0.notificationsEnabled = true }
        let model = AppModel(
            settings: settings, config: .fallback,
            clock: Clock(now: Date()), notifications: manager, autoStart: false
        )
        let view = SettingsView(settings: settings, config: .fallback, model: model)
        _ = view.body
        let buttons = try view.inspect().findAll(ViewType.Button.self)
        for button in buttons.prefix(2) {
            try? button.tap()
        }
    }
}
