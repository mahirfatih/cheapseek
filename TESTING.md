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
| `PeakCalculatorTests` (38) | `isPeak` windows and boundaries, weekends, `nextTransition` (incl. exact transition instants), `transitions` between dates, `schedules` (UTC, Istanbul, New York, DST day). | Pure functions — no mocks |
| `CountdownFormatterTests` (7) | Hours/minutes/seconds formatting, exact hour, negative clamp, hour-truncation spec. | Compares against the localized unit keys — language-independent |
| `AppSettingsTests` (6) | Defaults, `updateInterval`/notification clamping and persistence, timezone resolution, quiet-hours preferences. | Injected `UserDefaults` suite (hermetic) |
| `AppModelTests` (7) | `isPeak`/`schedule` from injected date + timezone, `setUpdateInterval`, language-change revision and notification reschedule, launch backfill (weekend gap, empty store). | Injected clock/timezone via `autoStart: false` |
| `MenuBarLabelTests` (6) | Menu bar status text for each `PeakStatus`, short-length guard, distinct non-empty symbols, accessibility titles, per-language status titles. | Pins the language to English via Localize |
| `NotificationManagerTests` (5) | Cancel-then-add scheduling, disabled settings clear pending, denied permission skips scheduling, permission state updates. | Mock `NotificationCenterClient` |
| `NotificationPlannerTests` (10) | Peak warning at `T−before`, off-peak/peak-start events, disabled options, past-date drop, 7-day horizon, quiet-hours suppression and wrap-around. | Pure functions with injected `now`/`PeakSchedule` |
| `HistoryAggregatorTests` (8) | Empty data, single day, full 7 days, timezone reassignment, DST spring-forward (23h) and fall-back (25h), window clipping, last-interval state. | Pure functions with injected `now`/`TimeZone` |
| `HistoryStoreTests` (17) | Event-based dedupe, persistence round-trip, prune anchor, in-memory mode, plus backfill: transitions+final sample, no-op guards, off-peak-only gap, peak→off→peak, full weekend, idempotency, 50-sample cap, DST 23/25h, non-UTC and half-hour zones. | Injected `UserDefaults` suite + in-memory store |
| `LocalizationTests` (4) | All 17 `.lproj` files have identical key sets; every expected key present in every language; notification/history/menu-bar strings are not left in English; every language resolves to a valid locale. | Direct source-file parsing — no bundle state |
| `PricingConfigTests` (6) | Bundled `Configuration.plist` is present and parses; fallback schedule matches DeepSeek defaults; custom schedule peak calculation; usage URL present. | Injected `PeakSchedule` — no mocks |
| `TimeZoneCatalogTests` (6) | System entry without a title, region grouping, city extraction (incl. 3-part identifiers), offset formatting, and case/diacritic-insensitive search filtering. | Injected identifier lists — no global state |
| `TimeZoneLabelTests` (5) | Identifier + offset labels, underscore prettifying, fixed-offset passthrough, offset formatting, and DST-aware offsets. | Pure functions with injected dates |
| `SecurityRegressionTests` (8) | OWASP/MASVS regression: no ATS arbitrary loads, no entitlements, no networking APIs, no analytics SDKs, no Keychain, no remote packages, `LSUIElement`, 17 languages present. | Source + `project.yml` assertions — no mocks |

> There is no unit test for the SwiftUI views (`PopupView`, `SettingsView`, `PricingInfoView`, `HistoryChartView`, `TimeZonePicker`): SwiftUI view bodies are not meaningfully unit-testable. Their rendering is covered by SwiftUI previews (light/dark) and manual verification. All charting/date math lives in the pure `HistoryAggregator` so it *is* unit-tested.

## Security Regression Suite (runs on every build)

`SecurityRegressionTests.swift` — if any check fails, the **build is rejected**:

| Check | Assurance |
| :--- | :--- |
| `testA05_noATSArbitraryLoads` | No `NSAllowsArbitraryLoads` in `project.yml` |
| `testA05_noEntitlementsDeclared` | The app declares no entitlements and is not sandboxed |
| `testMenuBarAgent_isLSUIElement` | Runs as a menu-bar-only agent (`LSUIElement`) |
| `test_noNetworkingAPIs` | No `URLSession` / `URLRequest` / `import Network` in app sources |
| `test_noAnalyticsOrTelemetrySDKs` | No Firebase/Sentry/Mixpanel/Analytics/Telemetry SDKs |
| `test_noKeychainOrSecretStorage` | No Keychain / `SecItem` usage (UserDefaults-only persistence) |
| `testA06_noRemotePackageDependencies` | No remote SPM packages (`url:` / `from:`); only the vendored Localize-Swift |
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
- Enforces a **coverage gate**: `CheapSeek.app` line coverage ≥ `0.25`.
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

`CheapSeek.app` line coverage: **29.77%** (CI gate ≥ 25% ✅ — SwiftUI views are intentionally untested by unit tests)

| File | Line Coverage |
| :--- | :--- |
| `CheapSeekApp.swift` | **100.00%** |
| `CountdownFormatter.swift` | **100.00%** |
| `MenuBarLabel.swift` | **100.00%** |
| `TimeZoneLabel.swift` | **100.00%** |
| `HistoryStore.swift` | 97.44% |
| `HistoryAggregator.swift` | 97.22% |
| `NotificationPlanner.swift` | 95.40% |
| `PeakCalculator.swift` | 93.65% |
| `NotificationManager.swift` | 92.00% |
| `TimeZoneCatalog.swift` | 91.55% |
| `AppModel.swift` | 91.46% |
| `Clock.swift` | 87.50% |
| `DeepSeekConfig.swift` | 80.49% |
| `AppSettings.swift` | 77.78% |
| `AppLanguage.swift` | 33.85% (enum — exercised via Settings picker) |
| `PeakStatus.swift` | 30.00% |
| `SettingsView.swift` | 0.94% (SwiftUI view) |
| `TimeZonePicker.swift` | 0.00% (SwiftUI view) |
| `PricingInfoView.swift` | 0.00% (SwiftUI view) |
| `PopupView.swift` | 0.00% (SwiftUI view) |
| `HistoryChartView.swift` | 0.00% (SwiftUI view) |

*Re-measure with `./test/test.sh --coverage`. Views are excluded from strict line-coverage gating.*
