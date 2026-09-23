# Contributing Guide

## Development Setup

1. Install XcodeGen: `brew install xcodegen`
2. Generate the project: `xcodegen generate`
3. Open `CheapSeek.xcodeproj` in Xcode
4. Press `Cmd + R` to build and run (the app lives in the menu bar)

> **Note:** `project.yml` is the canonical source. The `.xcodeproj` is generated and **gitignored** — never edit or commit it. Run `xcodegen generate` after any change to `project.yml` or after adding/removing source files.

### Local signing

The Apple team id is kept out of the repository:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig   # then set DEVELOPMENT_TEAM
```

`Config/Base.xcconfig` (committed) optionally `#include?`s `Config/Local.xcconfig`
(gitignored). Do not set signing in Xcode — the project is regenerated. See
[docs/RELEASE.md](./docs/RELEASE.md) for distribution signing.

## Running Tests

```bash
./test/test.sh            # unit tests (default)
./test/test.sh --list     # show the plan without running
./test/test.sh --ui       # include the UI tests (local only)
./test/test.sh --coverage # unit tests + coverage summary
./test/test.sh --no-gen   # skip project generation
```

### Test Flags

| Flag | Description |
| :--- | :--- |
| `--list` | Show the plan without running |
| `--no-gen` | Skip `xcodegen generate` |
| `--ui` | Include the UI tests (default: unit tests only) |
| `--coverage` | Enable code coverage and print an `xccov` summary |
| `--scheme <name>` | Override the Xcode scheme |
| `--project <path>` | Override the `.xcodeproj` path |
| `--destination <dest>` | Override the test destination |
| `--results-dir <dir>` | Override the `.xcresult` output directory |
| `--logs-dir <dir>` | Override the raw log output directory |

See [docs/TESTING.md](./docs/TESTING.md) for suite details and coverage expectations.

## Capturing Screenshots

`test/capture-screenshots.sh` regenerates `docs/screenshots`.

Screenshots are **never produced in CI** (`ScreenshotCaptureTests` is gated and
skips by default), so they go stale silently. **Re-run the script and inspect
the PNGs after any UI-affecting change** (views, chart, localization strings,
light/dark appearance) and commit the refreshed images together with the change.

## Keeping the Docs in Sync

When you change code, update the docs it affects **in the same commit**. This
keeps the README, overview, diagrams, and screenshots from drifting out of date.

| If you change… | Also update… |
| :--- | :--- |
| Any UI, view, layout, theme, or localization string | Run `./test/capture-screenshots.sh`, commit the refreshed `docs/screenshots/{light,dark}/*.png`, and update the gallery in `README.md` and `docs/screenshots/README.md`. |
| A feature or user-visible behavior | `README.md` (Features/Overview), `docs/OVERVIEW/EN.md` **and** `docs/OVERVIEW/TR.md`, and `CHANGELOG.md` (`Unreleased`). |
| Architecture, data flow, or app state | `docs/diagrams/*.json`, regenerate the matching `.html` with Archify, and update the README Architecture section + `docs/OVERVIEW`. |
| A source file is added/removed/renamed | `README.md` Project Structure; `docs/DEVELOPMENT.md` if tooling-related. |
| A `UserDefaults` key or the history model | `docs/DATABASE.md`. |
| `Configuration.plist` keys (peak windows, prices, links) | `docs/API.md` and the README Permissions & Privacy table. |
| A language, or any `*.lproj` key | All `*.lproj/Localizable.strings`, the README language list/count, `docs/OVERVIEW/*`, and the [Adding New Languages](#adding-new-languages) section below. |
| A test target, test flag, or coverage expectation | `docs/TESTING.md`, this file (Running Tests / CI), and the README Testing & CI section. |
| A script or CI workflow | `README.md` Project Structure, `docs/DEVELOPMENT.md`, `docs/RELEASE.md` / `docs/HOMEBREW.md`, and `scripts/README.md`. |
| The app version or a release | `project.yml` (`./scripts/bump-version.sh`), `CHANGELOG.md`, and the README version lines. |
| Security, entitlements, or privacy posture | `SECURITY.md`, the README Permissions & Privacy table, and `CheapSeek/PrivacyInfo.xcprivacy`. |

> Hardcoded numbers in docs (test counts, coverage %, language/key counts) drift
> easily. If your change affects one, update it — or omit the number.

## Commit Message Format

Write a **single, concise sentence** describing what the commit does, in the imperative mood:

```
Add UI test target with launch, popup, and settings checks
Fix countdown units for Turkish
```

Keep one logical change per commit.

## Code Style

- **Language:** Swift 5.9 / SwiftUI, macOS 14+
- **Architecture:** Pure logic (`PeakCalculator`, `CountdownFormatter`, `TimeZoneCatalog`, `TimeZoneLabel`) separated from state (`AppModel`, `AppSettings`) and views (`PopupView`, `SettingsView`, `TimeZonePicker`)
- **Concurrency:** UI updates on the main actor; `AppModel` is `@Observable` and refreshed by an async `Clock` (no `Timer` or Combine)
- **Localization:** Every user-facing string **must** use `"key".localized()`. Keys live in all 17 `*.lproj/Localizable.strings` files.
- **Theme:** Use semantic colors only (`.primary`, `.secondary`, `.regularMaterial`); never hardcode white/black.
- **Testability:** Pure functions must not touch global state. `AppSettings` accepts an injected `UserDefaults`; `AppModel` accepts an injected clock/timezone, `HistoryStore`, and `NotificationManager` (`autoStart: false` in tests) — use these in tests.
- **Privacy:** No analytics, crash reporters, networking, or third-party SDKs.

## Adding New Languages

1. Create `CheapSeek/<lang>.lproj/Localizable.strings` with **all** keys (copy `en.lproj` as a template).
2. Add a case to the `AppLanguage` enum in `CheapSeek/AppLanguage.swift` — code, endonym `displayName`, flag emoji, and `localeIdentifier` (the single source of truth for the language list).
3. Run `./test/test.sh` — `LocalizationTests` and `SecurityRegressionTests` verify key parity, completeness, and pack presence.

## Adding New Tests

1. Add the test file to `CheapSeekTests/` (unit) or `CheapSeekUITests/` (UI).
2. Follow the existing naming conventions (`*Tests.swift`).
3. Unit tests must be hermetic — use a unique `UserDefaults` suite or injected dates, never shared global state.
4. Security checks belong in `SecurityRegressionTests.swift` (they assert on `project.yml` and app sources).
5. Run `xcodegen generate` so the new file is added to the project (XcodeGen syncs the target folders).

## Key Files Reference

| File | Purpose |
| :--- | :--- |
| `project.yml` | XcodeGen spec — canonical source |
| `CheapSeek/` | App source (main target) |
| `CheapSeek/Configuration.plist` | Bundled config: peak hours, model pricing, links |
| `CheapSeek/DeepSeekConfig.swift` | Loads and decodes the bundled config (with fallback) |
| `CheapSeek/AppLanguage.swift` | Single source of truth for the 17 supported languages |
| `CheapSeek/Assets.xcassets/` | App icon + accent color |
| `CheapSeekTests/` | XCTest suite (unit + security regression + config) |
| `CheapSeekUITests/` | XCUITest suite (launch + best-effort menu bar checks) |
| `test/test.sh` | Single test runner script |
| `scripts/` | Helper scripts (see [`scripts/README.md`](./scripts/README.md)) |
| `.github/workflows/ci.yml` | CI workflow (lint + build + unit tests + coverage gate) |
| `.swiftlint.yml` | SwiftLint configuration (run with `--strict`) |
| `CHANGELOG.md` | Keep a Changelog release history |
| `README.md` | Installation, features, architecture |
| `docs/OVERVIEW/` | Detailed overview (EN / TR) |
| `docs/TESTING.md` | Detailed test strategy and coverage |
| `docs/DEVELOPMENT.md` | Local setup, project generation, and tooling |
| `docs/DATABASE.md` | UserDefaults settings and history persistence |
| `docs/API.md` | No network API; bundled config and links |
| `docs/RELEASE.md` | Sign, notarize, publish, and distribute |
| `docs/HOMEBREW.md` | Homebrew tap and cask guide |
| `docs/diagrams/` | Archify diagrams (interactive HTML + JSON) |
| `docs/screenshots/` | Light/dark UI screenshots and gallery |
| `SECURITY.md` | OWASP/MASVS security report |

## CI

`.github/workflows/ci.yml` (`macos-latest`, **manual dispatch only**):

- Runs SwiftLint (`swiftlint lint --strict`) as a separate `lint` job.
- Regenerates the project with `xcodegen`, builds, then runs the **unit tests** with coverage.
- Enforces a coverage gate (`CheapSeek.app` ≥ 95%).
- UI tests are **not** run in CI (macOS XCUITest needs an interactive GUI session); run them locally with `./test/test.sh --ui`.

## Dependency Notes

The only runtime dependency, **Localize-Swift 3.2.0**, is **vendored** under `Packages/Localize-Swift` and wired in `project.yml` as a local package. The test target additionally uses ViewInspector 0.10.3 as a test-only remote Swift Package dependency (not linked into the shipped app). Upstream's SPM target is iOS-only (it imports `UIKit` unconditionally in `Sources/UI`), so it cannot build for macOS as-is — do not switch it back to the remote URL without verifying macOS support.
