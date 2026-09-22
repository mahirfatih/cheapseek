# Development Guide

How to build, run, and work on CheapSeek locally. For shipping a build, see [RELEASE.md](./RELEASE.md).

---

## Prerequisites

| Requirement | Version / Notes |
| :--- | :--- |
| **macOS** | 14.0+ |
| **Xcode** | 15.0+ |
| **Project generator** | [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen` |
| **Linter** (optional) | [SwiftLint](https://github.com/realm/SwiftLint) — `brew install swiftlint` |

---

## Project generation

`project.yml` is the **single source of truth** for the Xcode project. The generated `CheapSeek.xcodeproj` is **not committed** (it is gitignored); run `xcodegen generate` after cloning.

```bash
xcodegen generate
```

Run `xcodegen generate` after **any** change to `project.yml` or after adding/removing source files (XcodeGen uses explicit file references, so new files are not picked up until the project is regenerated). Do **not** edit or commit the generated project.

Key points in `project.yml`:

- App target `CheapSeek` (`MenuBarExtra`; `LSUIElement = true` so there is no Dock icon).
- Unit test target `CheapSeekTests` and UI test target `CheapSeekUITests`; the scheme `CheapSeek` builds and tests all three.
- The only runtime dependency, **Localize-Swift 3.2.0**, is vendored under `Packages/Localize-Swift` as a local package (the upstream SPM target is iOS-only). `ViewInspector` is a test-only dependency.
- `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` are defined here — bump them with [`scripts/bump-version.sh`](../scripts/bump-version.sh).
- `configFiles` points at `Config/Base.xcconfig` for signing (see below).

---

## Signing

The Apple **team id is kept out of the repository** via a local, gitignored xcconfig:

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
# edit Config/Local.xcconfig → DEVELOPMENT_TEAM = XXXXXXXXXX
```

`project.yml` references `Config/Base.xcconfig`, which `#include?`s
`Config/Local.xcconfig`. Do **not** set signing in Xcode — the project is
regenerated and such changes are lost.

Distributable builds need **Developer ID Application** signing and
notarization — see [RELEASE.md](./RELEASE.md) and
[scripts/release.sh](../scripts/release.sh).

---

## Local verification

Run the same plan as CI before pushing:

```bash
./test/test.sh --coverage
swiftlint lint --strict
```

See **Tooling** below for the full command table and [TESTING.md](./TESTING.md) for suite details.

---

## Release

Bump the version with [`scripts/bump-version.sh`](../scripts/bump-version.sh), regenerate with `xcodegen generate`, then archive, sign, notarize, and distribute — see [RELEASE.md](./RELEASE.md) for the full checklist.

---

## Build & run

```bash
xcodegen generate
xcodebuild build -project CheapSeek.xcodeproj -scheme CheapSeek -configuration Debug -derivedDataPath build
```

Or open `CheapSeek.xcodeproj` in Xcode and press `Cmd + R`. The app has no Dock icon; look for it in the menu bar. Local settings live in `UserDefaults` and are described in [DATABASE.md](./DATABASE.md).

---

## Code signing & launch at login

> **DEV MODE:** Without a `Config/Local.xcconfig`, `Config/Base.xcconfig` signs ad-hoc (`CODE_SIGN_IDENTITY = -`). macOS may print harmless `com.apple.linkd.autoShortcut` connection messages at launch.

Because of the ad-hoc signature, `SMAppService.mainApp` may reject the launch-at-login registration. Set your `DEVELOPMENT_TEAM` in `Config/Local.xcconfig` for a properly signed build; distribution builds need Developer ID signing + notarization — see [RELEASE.md](./RELEASE.md).

`SMAppService` is wrapped by the `LoginItemService` protocol in `AppSettings.swift`, so the register/unregister behavior can be tested with a stub instead of touching the real login-item state.

---

## Tooling

| Command | Purpose |
| :--- | :--- |
| `./test/test.sh` | Unit tests (`xcodegen generate` + `xcodebuild test`) — see [TESTING.md](./TESTING.md) |
| `./test/test.sh --ui` | Include the UI tests (local only) |
| `./test/test.sh --coverage` | Unit tests plus an `xccov` coverage summary |
| `./test/capture-screenshots.sh` | Render the light/dark screenshots for `docs/screenshots/` — re-run after any UI-affecting change (CI never renders them) |
| `./scripts/release.sh` | Build a Release app + DMG (signed/notarized/published) — see [RELEASE.md](./RELEASE.md) |
| `./scripts/make-dmg.sh <app>` | Package a built `.app` into a DMG |
| `./scripts/update-cask.sh <version>` | Refresh the Homebrew cask — see [HOMEBREW.md](./HOMEBREW.md) |
| `swiftlint lint --strict` | Lint the app and test targets (`.swiftlint.yml`) |
| `./scripts/bump-version.sh 1.1.0` | Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` |

---

## Conventions

- **Language / framework:** Swift 5.9, SwiftUI, macOS 14+.
- **Architecture:** pure logic (`PeakCalculator`, `CountdownFormatter`, `NotificationPlanner`, `HistoryAggregator`, `TimeZoneCatalog`, `TimeZoneLabel`) separated from state (`AppModel`, `AppSettings`, `Clock`, `HistoryStore`, `NotificationManager`) and views.
- **Concurrency:** UI on the main actor; `AppModel` is `@Observable` and driven by an async `Clock` (no `Timer` or Combine).
- **Localization:** every user-facing string uses `"key".localized()` with keys in all 17 `*.lproj/Localizable.strings` files.
- **Theme:** semantic system colors only; never hardcode white/black.
- **Privacy:** no analytics, crash reporters, networking, or third-party runtime SDKs.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for the commit conventions and test expectations.
