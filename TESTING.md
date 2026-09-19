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
        │   UI    │  CheapSeekUITests (app launch; menu bar popup best-effort)
        ├─────────┤
        │  Unit   │  PeakCalculatorTests, CountdownFormatterTests,
        │         │  AppSettingsTests, AppModelTests, MenuBarLabelTests,
        │         │  NotificationManagerTests, NotificationPlannerTests,
        │         │  HistoryAggregatorTests, HistoryStoreTests,
        │         │  LocalizationTests, PricingConfigTests,
        │         │  TimeZoneCatalogTests, TimeZoneLabelTests,
        │         │  SecurityRegressionTests
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

## UI Tests (`CheapSeekUITests`, XCUITest)

Runs against the real app and covers:

- `testAppLaunches` — launches the app and asserts it is running.
- `testStatusItemOpensPopup` — locates the menu bar status item, clicks it, and asserts the popup title appears.
- `testSettingsControlsWhenPopupOpen` — opens the popup, clicks **Settings**, and asserts the Settings controls.

macOS does not reliably expose third-party menu bar (``MenuBarExtra`) status items to the accessibility tree, and the `.window` popup is not always reachable. When the status item or popup cannot be found, the affected tests **skip (`XCTSkip`)** instead of failing, so the suite stays green while documenting the limitation. `testAppLaunches` is always deterministic.

UI tests are intended to run **locally**; see CI below.

## CI

`.github/workflows/ci.yml` (`macos-latest`, on push / PR / manual dispatch):

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

- **Menu bar (`MenuBarExtra`) UI automation:** the status item and its `.window` popup are not reliably exposed to XCUITest on macOS — covered by `XCTSkip` and manual verification.
- **`SMAppService` registration:** `register()` / `unregister()` change real login-item state and can require user approval; not exercised in tests. `AppSettings` only reads `status`.
- **Menu bar tint rendering:** macOS may render the label as a monochrome template, so the app intentionally avoids color and uses `leaf`/`flame.fill` plus text; visual appearance is verified manually.
- **Notification delivery:** authorization prompts and actual banner delivery depend on a signed app and user approval; `NotificationManager` is tested through a mock client, while real delivery is verified manually.
- **History chart rendering:** the SwiftUI `Charts` view is not snapshot-tested; all date math is covered by `HistoryAggregatorTests` and the chart is verified manually.
- **SwiftUI snapshot tests:** SwiftUI previews + manual visual verification were deemed sufficient.

## Coverage Expectations

| Module | Target Coverage |
| :--- | :--- |
| `PeakCalculator.swift` | **90%+** |
| `CountdownFormatter.swift` | **100%** |
| `NotificationPlanner.swift` | **90%+** |
| `HistoryAggregator.swift` | **90%+** |
| `HistoryStore.swift` | **90%+** |
| `NotificationManager.swift` | **80%+** |
| `AppSettings.swift` | **70%+** |
| `AppModel.swift` | **70%+** |
| `Clock.swift` | **70%+** |
| SwiftUI views (`PopupView`, `SettingsView`, `PricingInfoView`, `HistoryChartView`, `TimeZonePicker`, `CheapSeekApp`) | Covered by UI tests / manual verification; excluded from strict gating |

## Measured Coverage (2026-09-18, local macOS run)

`CheapSeek.app` line coverage: **97.70%** (CI gate ≥ 95% ✅ — remaining lines are framework-deferred closures, property-wrapper attribution, dead fallbacks, and system boundaries; see "Excluded from coverage")

| File | Line Coverage |
| :--- | :--- |
| `AppLanguage.swift` | **100.00%** |
| `AppModel.swift` | **100.00%** |
| `AppSettings.swift` | **100.00%** |
| `CheapSeekApp.swift` | **100.00%** |
| `Clock.swift` | **100.00%** |
| `CountdownFormatter.swift` | **100.00%** |
| `DeepSeekConfig.swift` | **100.00%** |
| `MenuBarLabel.swift` | **100.00%** |
| `NotificationManager.swift` | **100.00%** |
| `PeakStatus.swift` | **100.00%** |
| `SystemUserNotificationCenterAdapter.swift` | **100.00%** (full local run; CI skips it) |
| `TimeZoneLabel.swift` | **100.00%** |
| `HistoryChartView.swift` | 99.22% (SwiftUI view) |
| `HistoryAggregator.swift` | 98.59% |
| `PricingInfoView.swift` | 98.38% (SwiftUI view) |
| `NotificationPlanner.swift` | 97.70% |
| `PopupView.swift` | 97.55% (SwiftUI view) |
| `HistoryStore.swift` | 97.44% |
| `TimeZonePicker.swift` | 97.39% (SwiftUI view) |
| `SettingsView.swift` | 96.04% (SwiftUI view) |
| `PeakCalculator.swift` | 96.03% |
| `TimeZoneCatalog.swift` | 92.96% |

*Re-measure with `./test/test.sh --coverage`.*

## Excluded from coverage

Views are covered in two layers: **ViewInspector** evaluates each view's `body` and lets tests tap controls, and **`ImageRenderer`** renders views offscreen, which executes the deferred `Chart`/`List`/`Form`/`TimelineView` content closures that ViewInspector does not materialize. Together they lifted view coverage from ~0% to ~96–99% and the target to **97.70%**.

The remaining `CheapSeek.app` lines are excluded by design (the gate is set to the highest stable measured value, `0.95`):

- **Framework-deferred closures that offscreen rendering still skips** — a SwiftUI `Picker`'s menu rows (e.g. the language list) and a `.sheet`'s content closure are built only when the menu/sheet is actually presented. Affected: a few lines in `SettingsView`, `TimeZonePicker`'s popover body, and `PopupView`'s `PopupHost` `openSettings`/`terminate` glue.
- **Property-wrapper attribution** — `@State`/`@Environment` storage initializers are sometimes reported as uncovered even though the view is constructed and rendered.
- **Dead fallback** — `PricingInfoView`'s `fallbackWindowText` requires `Calendar.date(from:)` to fail, which does not happen for valid windows.
- **System boundaries** — `SystemUserNotificationCenterAdapter` and `SystemLoginItemService.register/unregister` call the real `UNUserNotificationCenter`/`SMAppService`; they are exercised with bounded waits, but callbacks and side effects are OS-owned.
- **`@main` / scene glue** — `CheapSeekApp`'s `MenuBarExtra`/`Settings` scene wiring and `PopupHost`'s environment read are entry-point glue.

`xccov` additionally counts partial-line **subranges** (optional chaining, short-circuit operators, `OSLog` autoclosures). That is why a few pure/state files (e.g. `TimeZoneCatalog`, `PeakCalculator`) report 93–96% despite every branch having a test.

> **System-boundary tests:** `SystemUserNotificationCenterAdapterTests` and `SystemLoginItemServiceTests` intentionally touch real system APIs and use bounded waits (they never fail on a missing callback). To keep CI hermetic they are excluded from the CI job with `-skip-testing`; run them locally with `./test/test.sh` (they execute by default).
