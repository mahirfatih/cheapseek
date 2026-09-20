# Testing Guide

This repository is a **single-platform macOS menu bar app** (Swift/SwiftUI + Foundation). There is no network extension, database, or device-only subsystem, so the test strategy is straightforward: **XCTest** for all business logic, and a small **XCUITest** suite for app launch plus best-effort menu bar interaction.

## Quick Start

```bash
./test/test.sh --list            # show the plan without running
./test/test.sh                   # xcodegen generate + unit tests
./test/test.sh --ui              # include the UI tests
./test/test.sh --coverage        # unit tests + xccov coverage summary
./test/test.sh --no-gen          # skip project generation
```

Raw `xcodebuild` output is written to `logs/Test_<timestamp>.log` and result bundles to `test/TestResults/` (`logs/` and `*.xcresult` are in `.gitignore`, never committed).

Manual single-command run:

```bash
xcodebuild -project CheapSeek.xcodeproj \
  -scheme CheapSeek \
  -destination 'platform=macOS' \
  -only-testing:CheapSeekTests test
```

---

## Test Pyramid

```
        ┌─────────┐
        │  Manual │  Menu bar rendering, Settings interactions, SMAppService
        ├─────────┤
        │   UI    │  CheapSeekUITests (launch, settings, timezone picker; popup best-effort)
        ├─────────┤
        │  Unit   │  PeakCalculatorTests, CountdownFormatterTests,
        │         │  AppSettingsTests, AppModelTests, MenuBarLabelTests,
        │         │  NotificationManagerTests, NotificationPlannerTests,
        │         │  HistoryAggregatorTests, HistoryStoreTests,
        │         │  LocalizationTests, PricingConfigTests,
        │         │  TimeZoneCatalogTests, TimeZoneLabelTests,
        │         │  SecurityRegressionTests,
        │         │  ScreenshotCaptureTests (gated/skipped by default)
        └─────────┘
```

## Suites & Strategy

| Suite | Focus | Dependency Strategy |
| :--- | :--- | :--- |
| `PeakCalculatorTests` (39) | `isPeak` windows and boundaries, weekends, `nextTransition` (incl. exact transition instants), `transitions` between dates, `todaySchedules`, `schedules` (UTC, Istanbul, New York, DST day). | Pure functions — no mocks |
| `CountdownFormatterTests` (7) | Hours/minutes/seconds formatting, exact hour, negative clamp, hour-truncation spec. | Compares against the localized unit keys — language-independent |
| `AppSettingsTests` (7) | Defaults, `updateInterval`/notification clamping and persistence, timezone resolution, quiet-hours preferences, launch-at-login via a fake `LoginItemService`. | Injected `UserDefaults` suite + `LoginItemService` |
| `AppModelTests` (12) | `isPeak`/`schedule` from injected date + timezone, `setUpdateInterval`, language-change revision and notification reschedule, launch backfill (weekend gap, empty store), timezone-change backfill (LA/Kolkata/DST, idempotent, re-aggregation), tick callback, `hasHistory`. | Injected clock/timezone via `autoStart: false` |
| `MenuBarLabelTests` (6) | Menu bar status text for each `PeakStatus`, short-length guard, distinct non-empty symbols, accessibility titles, per-language status titles. | Pins the language to English via Localize |
| `NotificationManagerTests` (7) | Cancel-then-add scheduling, disabled settings clear pending, denied permission skips scheduling, permission state updates, `SystemNotificationCenterClient` delegation, no-op disabled client. | Mock `NotificationCenterClient` + fake `UserNotificationCenterAdapter` |
| `NotificationPlannerTests` (11) | Peak warning at `T−before`, off-peak/peak-start events, disabled options, past-date drop, 7-day horizon, quiet-hours suppression, wrap-around and same-day windows. | Pure functions with injected `now`/`PeakSchedule` |
| `HistoryAggregatorTests` (11) | Empty data, single day, full 7 days, timezone reassignment, DST spring-forward (23h) and fall-back (25h), window clipping, last-interval state, identifier, guarded durations. | Pure functions with injected `now`/`TimeZone` |
| `HistoryStoreTests` (18) | Event-based dedupe, persistence round-trip, prune anchor, in-memory mode, plus backfill: transitions+final sample, no-op guards, off-peak-only gap, peak→off→peak, full weekend, idempotency, 50-sample cap, DST 23/25h, non-UTC and half-hour zones. | Injected `UserDefaults` suite + in-memory store |
| `LocalizationTests` (4) | All 17 `.lproj` files have identical key sets; every expected key present in every language; notification/history/menu-bar strings are not left in English; every language resolves to a valid locale. | Direct source-file parsing — no bundle state |
| `PricingConfigTests` (6) | Bundled `Configuration.plist` is present and parses; fallback schedule matches DeepSeek defaults; custom schedule peak calculation; usage URL present. | Injected `PeakSchedule` — no mocks |
| `TimeZoneCatalogTests` (6) | System entry without a title, region grouping, city extraction (incl. 3-part identifiers), offset formatting, and case/diacritic-insensitive search filtering. | Injected identifier lists — no global state |
| `TimeZoneLabelTests` (5) | Identifier + offset labels, underscore prettifying, fixed-offset passthrough, offset formatting, and DST-aware offsets. | Pure functions with injected dates |
| `DeepSeekConfigTests` (10) | `decode` for nil/malformed/invalid/valid data, `load` fallback from a bundle without the plist, validation branches, UTC schedule. | Injected `Data` — no bundle state |
| `AppLanguageTests` (2) | All 17 cases expose non-empty, unique `displayName`/`flag`/`localeIdentifier`/`locale`. | Pure enum iteration |
| `ClockTests` (3) | Ticks fire on schedule, restarting cancels the previous task, stop without start is safe. | Real async clock with short intervals + expectations |
| `PeakStatusTests` (6) | `isPeak` init, titles/colors/symbols, badge body + accessibility label. | Pure values + ViewInspector |
| `PricingInfoViewTests` (3) | Scrollable/flat render, every model row, links present. | ViewInspector |
| `PopupViewTests` (6) | Popup/subviews render, status helpers, action buttons. | ViewInspector |
| `SettingsViewTests` (6) | Default/notification/quiet/denied variants render, bindings read/write, quiet date math, pricing sheet. | ViewInspector |
| `TimeZonePickerTests` (6) | Selected label, grouped content, empty result, selection callback, system entry. | ViewInspector |
| `HistoryChartViewTests` (4) | Empty state, chart properties, single/7-day rendering. | ViewInspector |
| `HistoryChartViewRenderTests` (2) | Offscreen `ImageRenderer` executes the `Chart`/`AxisMarks` builders. | `ImageRenderer` |
| `ViewRenderTests` (15) | Offscreen `ImageRenderer` renders every view + variant; button taps and binding writes. | `ImageRenderer` + ViewInspector |
| `ScreenshotCaptureTests` (1) | Offscreen light/dark PNG rendering of the popup, pricing, settings, and timezone picker. **Skipped by default** (`XCTSkipUnless`) and only runs with `TEST_RUNNER_CAPTURE_SCREENSHOTS=1` (see `test/capture-screenshots.sh`). | `ImageRenderer` + process environment |
| `SystemUserNotificationCenterAdapterTests` (1) | Exercises the real `UNUserNotificationCenter` adapter with bounded waits. | Real system API — excluded from the CI job via `-skip-testing` |
| `SystemLoginItemServiceTests` (1) | Exercises the real `SMAppService` wrapper with cleanup. | Real system API — excluded from the CI job via `-skip-testing` |
| `SecurityRegressionTests` (10) | OWASP/MASVS regression: no ATS arbitrary loads, no entitlements (declared or file), no networking APIs, no analytics SDKs, no Keychain, no remote packages in the app target, `LSUIElement`, privacy required-reason API, 17 languages present. | Source + `project.yml` assertions — no mocks |

> **Views are unit-tested in two layers:** ViewInspector evaluates each view's `body` and lets tests tap controls, and `ImageRenderer` renders views offscreen, which executes the deferred `Chart`/`List`/`Form`/`TimelineView` content closures. This lifted view coverage from ~0% to ~96–99%. See **Excluded from coverage** for the framework/system lines that remain.

## Security Regression Suite (runs on every build)

`SecurityRegressionTests.swift` — if any check fails, the **build is rejected**:

| Check | Assurance |
| :--- | :--- |
| `testA05_noATSArbitraryLoads` | No `NSAllowsArbitraryLoads` in `project.yml` |
| `testA05_noEntitlementsDeclared` | The app declares no entitlements and is not sandboxed |
| `testA05_noEntitlementsFilePresent` | No `*.entitlements` file exists in the repository |
| `testMenuBarAgent_isLSUIElement` | Runs as a menu-bar-only agent (`LSUIElement`) |
| `test_noNetworkingAPIs` | No `URLSession` / `URLRequest` / `import Network` / `import CFNetwork` in app sources |
| `test_noAnalyticsOrTelemetrySDKs` | No Firebase/Sentry/Mixpanel/Analytics/Telemetry SDKs |
| `test_noKeychainOrSecretStorage` | No Keychain / `SecItem` usage (UserDefaults-only persistence) |
| `testPrivacyManifestDeclaresRequiredReasonAPI` | `PrivacyInfo.xcprivacy` declares the UserDefaults required-reason code `CA92.1` |
| `testA06_noRemotePackageDependencies` | The app target has no remote SPM packages (`url:` / `from:`); only the vendored Localize-Swift |
| `testLocalizations_allLanguagesPresent` | All 17 `.lproj` packs exist |

## UI Tests

Runs against the real app and asserts via accessibility identifiers. Run locally with
`./test/test.sh --ui`.

### UI test mode

A menu-bar-only agent (`LSUIElement`) has no hittable menu bar, and macOS exposes no public API to
open the `MenuBarExtra` popup, so the UI tests launch with test-only arguments:

- **`-UITestMode 1`** — disables real notification scheduling and launch-at-login registration,
  renders the status block at a **fixed instant** (Monday 02:00 UTC → deterministic peak) instead
  of the wall-clock `TimelineView`, and presents the popup in a plain window so the `popup.*`
  identifiers are reachable.
- **`-UITestSettings`** — additionally presents the Settings screen in a plain window.

Both flags are test-only; production behavior is identical when they are absent.

| Test | Result | What it checks |
| :--- | :--- | :--- |
| `testAppLaunches` | **assert** | The app is running after launch. |
| `testSettingsOpensAndListsLanguages` | **assert** | `settings.language` lists exactly 17 languages. |
| `testSettingsTimezonePickerOpens` | **assert** | `settings.timezone` opens its popover and the search field filters to Tokyo. |
| `testQuitMenuItemExists` | **assert** | The Quit command (⌘Q) terminates the app. |
| `testPopupOpensAndShowsStatus` | **assert** | `popup.root`, `popup.status` (peak/off-peak), `popup.countdown`, and the history toggle/chart. |
| `testPopupPricingSheetOpens` | **assert** | `popup.pricing.button` opens `pricing.root` with a model row. |
| `testPopupQuitButtonExists` | **assert** | `popup.quit.button` exists and is hittable. |

All **7 UI tests assert real behavior; none skip**. Tested on macOS **26.6.2 (Build 25G83)**; the
deployment target is macOS 14+. UI tests are intended to run **locally**; see CI below.

## CI

`.github/workflows/ci.yml` (`macos-latest`, **manual dispatch only**):

- Installs XcodeGen, then `xcodegen generate` (`project.yml` is canonical).
- Builds the app.
- Runs the **unit tests only** (`-only-testing:CheapSeekTests`) with `-enableCodeCoverage YES`.
- Enforces a **coverage gate**: `CheapSeek.app` line coverage ≥ `0.95`.
- Uploads the `.xcresult` bundle as an artifact.

> UI tests are excluded from CI: macOS XCUITest requires an interactive GUI session and accessibility permissions, which GitHub-hosted runners do not provide reliably. Run `./test/test.sh --ui` locally instead.

## Command Reference (Same as CI)

```bash
# Local equivalent of a CI job (unit tests + coverage)
./test/test.sh --coverage

# Everything, including UI tests (local only)
./test/test.sh --ui
```

## Deliberately Out of Scope

- **Real `MenuBarExtra` click-through:** the status item is not reliably exposed to XCUITest and macOS has no public API to open the popup, so UI tests use test-only plain windows (`-UITestMode` / `-UITestSettings`); the production popup remains covered by the unit view tests and manual verification.
- **`SMAppService` registration:** `register()` / `unregister()` change real login-item state and can require user approval; not exercised in tests. `AppSettings` only reads `status`.
- **Menu bar tint rendering:** macOS may render the label as a monochrome template, so the app intentionally avoids color and uses `leaf`/`flame.fill` plus text; visual appearance is verified manually.
- **Notification delivery:** authorization prompts and actual banner delivery depend on a signed app and user approval; `NotificationManager` is tested through a mock client, while real delivery is verified manually.
- **History chart rendering:** the SwiftUI `Charts` view is not snapshot-tested; all date math is covered by `HistoryAggregatorTests` and the chart is verified manually.
- **SwiftUI snapshot tests:** SwiftUI previews + manual visual verification were deemed sufficient.

## Coverage

### Measured Coverage (2026-09-20, local macOS run)

`CheapSeek.app` line coverage: **95.54%** (2742/2870 lines).

**CI coverage gate:** `.github/workflows/ci.yml` enforces an **app-wide** `CheapSeek.app` line coverage of **≥ 95%** (`COVERAGE_MIN: "0.95"`). CI does **not** enforce any per-file minimum — the table below is a measurement, not a target.

The figure above is the local full run (both system-boundary tests included). CI skips `SystemUserNotificationCenterAdapterTests` and `SystemLoginItemServiceTests`, so its number can differ by roughly 0.5 percentage points; the gate is 95%.

| File | Line coverage | Notes |
| :--- | :--- | :--- |
| `AppLanguage.swift` | 100.00% | pure logic, no I/O |
| `AppModel.swift` | 100.00% | state/orchestration, injected dependencies |
| `AppSettings.swift` | 100.00% | `UserDefaults` persistence, in-memory suite in tests |
| `Clock.swift` | 100.00% | pure scheduling logic |
| `CountdownFormatter.swift` | 100.00% | pure formatting |
| `DeepSeekConfig.swift` | 100.00% | pure config |
| `MenuBarLabel.swift` | 100.00% | pure label logic |
| `NotificationManager.swift` | 100.00% | injected notification center |
| `PeakStatus.swift` | 100.00% | pure value type |
| `SystemUserNotificationCenterAdapter.swift` | 100.00% | system boundary — exercised locally; CI skips this test |
| `TimeZoneLabel.swift` | 100.00% | pure formatting |
| `HistoryChartView.swift` | 99.24% | SwiftUI view — ViewInspector + ImageRenderer |
| `HistoryAggregator.swift` | 98.59% | pure aggregation |
| `PricingInfoView.swift` | 98.39% | SwiftUI view — ViewInspector + ImageRenderer |
| `NotificationPlanner.swift` | 97.70% | pure planning |
| `PopupView.swift` | 97.47% | SwiftUI view — ViewInspector + ImageRenderer |
| `HistoryStore.swift` | 97.44% | file persistence, temp dirs in tests |
| `TimeZonePicker.swift` | 97.39% | SwiftUI view — ViewInspector + ImageRenderer |
| `SettingsView.swift` | 96.15% | SwiftUI view — ViewInspector + ImageRenderer |
| `PeakCalculator.swift` | 96.03% | pure logic; remainder is `xccov` partial-line subranges |
| `TimeZoneCatalog.swift` | 92.96% | pure catalog; remainder is `xccov` partial-line subranges |
| `CheapSeekApp.swift` | 40.19% | `@main`/scene glue + UI-test-only window bootstrap |

`DesignSystem.swift` is the only file under `CheapSeek/` absent from the report: it contains only `static let` constants, which `xccov` does not instrument.

### How to reproduce

```bash
./test/test.sh --coverage                                              # writes test/TestResults/Test_<stamp>.xcresult
xcrun xccov view --report --only-targets  <xcresult>                   # app-wide total
xcrun xccov view --report --files-for-target CheapSeek.app <xcresult>  # per-file table above
```

### Excluded from coverage

Views are covered in two layers: **ViewInspector** evaluates each view's `body` and lets tests tap controls, and **`ImageRenderer`** renders views offscreen, which executes the deferred `Chart`/`List`/`Form`/`TimelineView` content closures that ViewInspector does not materialize. Together they lifted view coverage from ~0% to ~96–99%.

The remaining uncovered `CheapSeek.app` lines (the ~4.5% below 100% in the measurement above) fall into these buckets — the CI gate, `0.95`, is a floor *below* the measured value, not a value derived from these exclusions:

- **Framework-deferred closures that offscreen rendering still skips** — a SwiftUI `Picker`'s menu rows (e.g. the language list) and a `.sheet`'s content closure are built only when the menu/sheet is actually presented. Affected: a few lines in `SettingsView`, `TimeZonePicker`'s popover body, and `PopupView`'s `PopupHost` `openSettings`/`terminate` glue.
- **Property-wrapper attribution** — `@State`/`@Environment` storage initializers are sometimes reported as uncovered even though the view is constructed and rendered.
- **Dead fallback** — `PricingInfoView`'s `fallbackWindowText` requires `Calendar.date(from:)` to fail, which does not happen for valid windows.
- **System boundaries** — `SystemUserNotificationCenterAdapter` and `SystemLoginItemService.register/unregister` call the real `UNUserNotificationCenter`/`SMAppService`; they are exercised with bounded waits, but callbacks and side effects are OS-owned.
- **`@main` / scene glue** — `CheapSeekApp`'s `MenuBarExtra`/`Settings` scene wiring, the UI-test-only window bootstraps (`-UITestMode` popup window and `-UITestSettings`), `NoopLoginItemService`, and `PopupHost`'s environment read are entry-point/UI-test glue.

`xccov` additionally counts partial-line **subranges** (optional chaining, short-circuit operators, `OSLog` autoclosures). That is why a few pure/state files (e.g. `TimeZoneCatalog`, `PeakCalculator`) report 93–96% despite every branch having a test.

> **System-boundary tests:** `SystemUserNotificationCenterAdapterTests` and `SystemLoginItemServiceTests` intentionally touch real system APIs and use bounded waits (they never fail on a missing callback). To keep CI hermetic they are excluded from the CI job with `-skip-testing`; run them locally with `./test/test.sh` (they execute by default).
