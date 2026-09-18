# Changelog

All notable changes to CheapSeek are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Searchable, region-grouped timezone picker with live UTC offsets.
- History backfill: gaps while the app was closed are recomputed on launch and on timezone change.
- ViewInspector + `ImageRenderer` unit-test layers and a 95% line-coverage gate in CI.

### Changed

- Grouped, System Settings–style layout for the Settings window.
- Language changes now refresh the popup, settings, menu bar, and pending notifications without a relaunch.

## [1.0.0] - 2026-09-15

### Added

- Peak/off-peak status in the menu bar, today's schedule, and a live next-transition countdown.
- Local peak/off-peak notifications with a before-peak warning and quiet hours.
- Pricing info (per 1M tokens) and a 7-day history chart.
- 17 languages with live switching, on-device only (no network, no telemetry).
