# CheapSeek — Overview

**English** · [Türkçe](./TR.md)

CheapSeek is a tiny **macOS menu bar app** that tells you whether the DeepSeek API is currently in **peak** (expensive) or **off-peak** (cheap) pricing. It is written in SwiftUI and computes the price window **entirely on-device** from the current UTC time. Its purpose is simple: code while it's cheap, wait while it isn't — with a live menu bar status, today's schedule, a countdown to the next change, local notifications, and a 7-day history chart.

---

## How it works

1. `Clock` ticks on a configurable interval (default **60s**) and hands the current date to `AppModel`.
2. `AppModel` asks the pure `PeakCalculator` whether that instant is peak, using a UTC calendar and half-open windows (`[01:00,04:00)` and `[06:00,10:00)`).
3. The menu bar label renders `leaf` + `cheap` for off-peak or `flame.fill` + `peak` for peak.
4. Opening the popup starts a per-second `TimelineView`: it shows the status badge, the current time and timezone, today's full schedule, and a live countdown to the next transition.
5. On launch and on any notification/timezone setting change, `NotificationManager` reschedules local notifications over a 7-day horizon (skipping quiet hours).
6. Each state change is recorded to `HistoryStore`; the gap while the app was closed is **backfilled on launch and on a timezone change**, so the chart stays accurate.

The key point: **there is no network call and no account.** The verdict is computed on-device from the system clock and UTC rules.

---

## Screens and features

### Menu bar

- Short text + symbol: `leaf` + `cheap` when off-peak, `flame.fill` + `peak` when expensive.
- Uses text rather than color only, so it stays readable in light, dark, and monochrome template mode.

### Popup

- Status badge (**Peak Hours** / **Off-Peak**), the current time, and the selected timezone (e.g. `America/Los Angeles · GMT-7`).
- **Today's Schedule:** every peak/off-peak segment for the day in your timezone.
- **Next Change:** a live countdown to the next transition (`in 3h 42m to Peak`).
- A collapsible **History** chart (last 7 days, peak share normalized against each calendar day; the in-progress day is marked separately).
- Actions: **Settings**, **Pricing**, **About**, **Quit**.

### About

- App icon, name, and version, with links to **labrus.com** and **info@labrus.com** (reachable from the popup footer and the Settings header).

### Pricing / info

- DeepSeek model rates per 1M tokens, with **peak** and **off-peak** prices side by side.
- The UTC peak window and its equivalent in your timezone.
- Links to the pricing page, API docs, and API usage.

### Timezone picker

- A searchable, region-grouped list of IANA timezones with live UTC offsets.
- Filter by city or identifier; the current selection is highlighted.

### Settings

- **Language** — 17 languages; the change applies instantly, no relaunch.
- **Timezone** — any IANA identifier, or `System Timezone`.
- **Notifications** — enable alerts, an off-peak-start alert, a peak-start alert, a before-peak warning, and quiet hours.
- **Launch at Login** — via `SMAppService`.
- **Update Interval** — 30–300s (default 60s).
- **History Reset** — clear recorded peak/off-peak history after confirmation.

---

## Peak logic

Peak windows are **UTC** and applied Monday–Friday; weekends are always off-peak.

| Window (UTC) | Days | Price |
| :--- | :--- | :--- |
| `01:00–04:00` | Mon–Fri | Peak (full price) |
| `06:00–10:00` | Mon–Fri | Peak (full price) |
| Everything else (incl. weekends) | — | Off-peak (50% off) |

- Windows are **half-open**: `01:00` is peak, `04:00` is off-peak.
- A custom `Configuration.plist` can override the windows, the weekday rule, prices, and links; `DeepSeekConfigTests` validates it and falls back to the built-in defaults if it is missing or malformed.

---

## Architecture and data layer

- **Pure core:** `PeakCalculator`, `CountdownFormatter`, `NotificationPlanner`, `HistoryAggregator`, `TimeZoneCatalog`, `TimeZoneLabel` — Foundation-only, fully unit-tested, no global state.
- **State:** `AppModel` (`@MainActor`, `@Observable`; refresh tick, schedule, history) + `AppSettings` (`UserDefaults` persistence, `SMAppService`) + `Clock` (async ticker) + `HistoryStore` + `NotificationManager`.
- **Config:** `DeepSeekConfig` loads `Configuration.plist` (peak windows, prices, links) with a built-in fallback.
- **Views:** `PopupHost`/`PopupView` (`MenuBarExtra` `.window`), `SettingsView`, `PricingInfoView`, `HistoryChartView` (Swift Charts), `TimeZonePicker`, `MenuBarLabel`, `PeakStatus`.
- **History:** event-based — a sample is written only on a state change, in `UserDefaults`; entries are pruned to the last 7 calendar days with a boundary anchor, and `HistoryAggregator` splits intervals into per-local-day peak/off-peak shares (DST-sized 23h/25h days included). Settings can clear history through a confirmed reset.

---

## Privacy and design

- **100% on-device:** no analytics, no telemetry, no network calls, no third-party runtime SDKs.
- State lives only in `UserDefaults` (timezone, notification preferences, quiet hours, refresh interval, language, history samples); `PrivacyInfo.xcprivacy` declares the UserDefaults required-reason API (`CA92.1`).
- **No entitlements**; runs as a menu-bar-only agent (`LSUIElement`).
- **Design:** semantic system colors, a `.regularMaterial` popup background, and automatic light/dark mode.

---

## Known limitations

- **Ad-hoc signing:** the project is ad-hoc signed by default, so `SMAppService` launch-at-login may fail to register until it is signed with a Development Team.
- **Menu bar appearance:** macOS may render the status item as a monochrome template; the indicator therefore uses short text plus distinct SF Symbols instead of color.
- **History while closed:** samples are recorded only while the app is running; the gap is backfilled on the next launch and on a timezone change.
- **Notifications:** local alerts depend on macOS notification permission and are scheduled on-device for the upcoming 7 days.

---

## Quality, testing, and project management

- **Tests:** **224 unit tests** (pure core, state, managers, localization, security, plus ViewInspector and offscreen `ImageRenderer` view tests) and **7 UI tests** (launch, Settings, timezone picker, popup — all assert).
- **Coverage:** `CheapSeek.app` line coverage **95.22%** (latest local full run) with a CI gate of **≥95%**.
- **CI:** GitHub Actions (`.github/workflows/ci.yml`) on **manual dispatch (`workflow_dispatch`) only** — a SwiftLint (`--strict`) job, `xcodegen generate`, build, unit tests with coverage, and the coverage gate.
- **Project management:** `project.yml` (XcodeGen) is the single source of truth; docs and assets live in `docs/diagrams/` (Archify) and `docs/screenshots/`.
- **Release:** `MARKETING_VERSION` in `project.yml` is bumped, then the app is archived, signed, exported, notarized, stapled, and packaged for distribution.

---

In short: CheapSeek turns DeepSeek's peak/off-peak pricing into a glanceable menu bar signal — computed on-device from UTC rules, with a live schedule, countdown, notifications, and history.
