# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **About** sheet (app icon, version, labrus.com and info@labrus.com links) reachable from the popup footer and the Settings header.
- Distribution tooling: `scripts/release.sh` (sign + notarize + publish), `scripts/make-dmg.sh`, and `scripts/update-cask.sh`.
- Homebrew tap `mahirfatih/tap` with a `cheapseek` cask, documented in [docs/HOMEBREW.md](./docs/HOMEBREW.md).
- `Config/` xcconfig signing model so the Apple team id never enters the repository.
- `ExportOptions.plist.example` for Developer ID exports.
- Searchable, region-grouped timezone picker with live UTC offsets.
- History backfill: gaps while the app was closed are recomputed on launch and on timezone change.
- Percentage-normalized 7-day history chart with a separate in-progress-day marker.
- Confirmed Settings action for clearing history.
- ViewInspector + `ImageRenderer` unit-test layers, a **95%** line-coverage gate in CI, and the new About view tests.

### Changed

- The generated `CheapSeek.xcodeproj` is now **gitignored** — run `xcodegen generate` after cloning; commits no longer include it.
- Pinned the test-only ViewInspector dependency to an exact version (`0.10.3`).
- Pricing and About use distinct action icons (`dollarsign.circle` / `info.circle`).
- Grouped, System Settings–style layout for the Settings window.
- Language changes now refresh the popup, settings, menu bar, and pending notifications without a relaunch.
- Timezone-aware history retention, single-write recording, and corrected history reaggregation/reset behavior.

## [1.0.0] - 2026-09-15

### Added

- Peak/off-peak status in the menu bar, today's schedule, and a live next-transition countdown.
- Local peak/off-peak notifications with a before-peak warning and quiet hours.
- Pricing info (per 1M tokens) and a 7-day history chart.
- 17 languages with live switching, on-device only (no network, no telemetry).
