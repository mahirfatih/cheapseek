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

`project.yml` is the **single source of truth** for the Xcode project. The committed `CheapSeek.xcodeproj` is generated from it and must never be edited by hand.

```bash
xcodegen generate
```

Run `xcodegen generate` after **any** change to `project.yml` or after adding/removing source files (XcodeGen uses explicit file references, so new files are not picked up until the project is regenerated). Commit the regenerated `.xcodeproj` alongside the change.

Key points in `project.yml`:

- App target `CheapSeek` (`MenuBarExtra`; `LSUIElement = true` so there is no Dock icon).
- Unit test target `CheapSeekTests` and UI test target `CheapSeekUITests`; the scheme `CheapSeek` builds and tests all three.
- The only runtime dependency, **Localize-Swift 3.2.0**, is vendored under `Packages/Localize-Swift` as a local package (the upstream SPM target is iOS-only). `ViewInspector` is a test-only dependency.
- `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` are defined here — bump them with [`scripts/bump-version.sh`](../scripts/bump-version.sh).

---

## Signing

Distributable builds must be signed with a **Developer ID Application** certificate (direct download) or an **Apple Distribution** certificate (Mac App Store); local builds are ad-hoc signed by default. The signing and launch-at-login details are covered under **Code signing & launch at login** below.

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

> **DEV MODE:** The project is **ad-hoc signed** by default (`CODE_SIGN_IDENTITY: "-"` in `project.yml`). macOS may print harmless `com.apple.linkd.autoShortcut` connection messages at launch.

Because of the ad-hoc signature, `SMAppService.mainApp` may reject the launch-at-login registration. Set a `DEVELOPMENT_TEAM` in `project.yml` (or a signing team in Xcode) for a properly signed build; distribution builds need Developer ID / Apple Distribution signing — see [RELEASE.md](./RELEASE.md).

`SMAppService` is wrapped by the `LoginItemService` protocol in `AppSettings.swift`, so the register/unregister behavior can be tested with a stub instead of touching the real login-item state.

---

## Tooling

| Command | Purpose |
| :--- | :--- |
| `./test/test.sh` | Unit tests (`xcodegen generate` + `xcodebuild test`) — see [TESTING.md](./TESTING.md) |
| `./test/test.sh --ui` | Include the UI tests (local only) |
| `./test/test.sh --coverage` | Unit tests plus an `xccov` coverage summary |
| `./test/capture-screenshots.sh` | Render the light/dark screenshots for `docs/screenshots/` — re-run after any UI-affecting change (CI never renders them) |
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
