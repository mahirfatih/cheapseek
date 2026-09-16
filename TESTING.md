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
        │         │  AppSettingsTests, AppModelTests, LocalizationTests,
        │         │  PricingConfigTests, SecurityRegressionTests
        └─────────┘
```

## Suites & Strategy

| Suite | Focus | Dependency Strategy |
| :--- | :--- | :--- |
| `PeakCalculatorTests` (33) | `isPeak` windows and boundaries, weekends, `nextTransition` (incl. exact transition instants), `schedules` (UTC, Istanbul, New York, DST day). | Pure functions — no mocks |
| `CountdownFormatterTests` (7) | Hours/minutes/seconds formatting, exact hour, negative clamp, hour-truncation spec. | Compares against the localized unit keys — language-independent |
| `AppSettingsTests` (4) | Defaults, `updateInterval` clamping, timezone resolution, persistence. | Injected `UserDefaults` suite (hermetic) |
| `AppModelTests` (4) | `isPeak`/`schedule` from injected date + timezone, `refresh()`, language-change revision. | Injected clock/timezone via `autoRefresh: false` |
| `LocalizationTests` (3) | All 10 `.lproj` files have identical key sets; every expected key present in every language; every language resolves to a valid locale. | Direct source-file parsing — no bundle state |
| `PricingConfigTests` (6) | Bundled `Configuration.plist` is present and parses; fallback schedule matches DeepSeek defaults; custom schedule peak calculation; usage URL present. | Injected `PeakSchedule` — no mocks |
| `SecurityRegressionTests` (8) | OWASP/MASVS regression: no ATS arbitrary loads, no entitlements, no networking APIs, no analytics SDKs, no Keychain, no remote packages, `LSUIElement`, 10 languages present. | Source + `project.yml` assertions — no mocks |

> There is no unit test for the SwiftUI views (`PopupView`, `SettingsView`): SwiftUI view bodies are not meaningfully unit-testable. Rendering is covered by SwiftUI previews (light/dark) and manual verification.

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
| `testLocalizations_allLanguagesPresent` | All 10 `.lproj` packs exist |

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
- Enforces a **coverage gate**: `CheapSeek.app` line coverage ≥ `0.20`.
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
- **Menu bar tint rendering:** macOS may render the label as a monochrome template, so red/green is verified manually.
- **SwiftUI snapshot tests:** SwiftUI previews + manual visual verification were deemed sufficient.

## Coverage Expectations

| Module | Target Coverage |
| :--- | :--- |
| `PeakCalculator.swift` | **90%+** |
| `CountdownFormatter.swift` | **100%** |
| `AppSettings.swift` | **70%+** |
| `AppModel.swift` | **70%+** |
| SwiftUI views (`PopupView`, `SettingsView`, `CheapSeekApp`) | Covered by UI tests / manual verification; excluded from strict gating |

## Measured Coverage (2026-09-15, local macOS run)

`CheapSeek.app` line coverage: **23.40%** (CI gate ≥ 20% ✅ — views are intentionally untested by unit tests)

| File | Line Coverage |
| :--- | :--- |
| `CountdownFormatter.swift` | **100.00%** |
| `PeakCalculator.swift` | 96.23% |
| `CheapSeekApp.swift` | 95.35% |
| `DeepSeekConfig.swift` | 93.33% |
| `AppModel.swift` | 79.12% |
| `AppSettings.swift` | 78.08% |
| `SettingsView.swift` | 2.71% (SwiftUI view) |
| `AppLanguage.swift` | 0.00% (enum — exercised via Settings picker) |
| `PopupView.swift` | 0.00% (SwiftUI view) |
| `PricingInfoView.swift` | 0.00% (SwiftUI view) |

*Re-measure with `./test/test.sh --coverage`. Views are excluded from strict line-coverage gating.*
