# Data & Persistence

CheapSeek has **no database and no network store**. All state is local and lives in `UserDefaults`:

- **Settings** — one key per preference, written as they change (`AppSettings`).
- **History** — a single JSON blob (`history.samples.v1`) holding the recorded peak/off-peak state changes (`HistoryStore`).

There is no SQLite, Core Data, or external storage. `PrivacyInfo.xcprivacy` declares the UserDefaults required-reason API (`CA92.1`).

---

## Settings

`AppSettings` (`CheapSeek/AppSettings.swift`) reads defaults on init and writes each property in its `didSet`. Keys:

| Key | Type | Default | Meaning |
| :--- | :--- | :--- | :--- |
| `settings.timeZone` | `String` | `""` | IANA identifier; empty means the system timezone |
| `settings.notificationsEnabled` | `Bool` | `false` | Master notification switch |
| `settings.updateInterval` | `Double` | `60` | Clock tick interval, clamped to `30...300` seconds |
| `settings.notifyBeforePeakMinutes` | `Int` | `5` | Before-peak warning lead time, clamped to `0...60` |
| `settings.notifyOnOffPeakStart` | `Bool` | `true` | Alert when off-peak starts |
| `settings.notifyOnPeakStart` | `Bool` | `false` | Alert when peak starts |
| `settings.quietHoursEnabled` | `Bool` | `false` | Suppress alerts inside the quiet window |
| `settings.quietHoursStart` | `Int` | `1380` (23:00) | Quiet-hours start, minutes from midnight |
| `settings.quietHoursEnd` | `Int` | `420` (07:00) | Quiet-hours end, minutes from midnight |

Numbers are normalized/clamped on load, so a corrupt or out-of-range value falls back to a safe default. The language selection is stored by Localize-Swift under its own key.

Launch-at-login is **not** stored by the app; it is read live from `SMAppService.mainApp.status` (see `AppSettings.swift`).

---

## History

### Model

```swift
struct HistorySample: Codable, Equatable {
    let timestamp: Date
    let isPeak: Bool
}
```

The array is JSON-encoded with `JSONEncoder` and stored under the single key `history.samples.v1`.

### Recording (event-based)

A sample is appended only when the peak/off-peak **state changes** (not every tick), so a typical day stores a handful of entries. `HistoryStore.record(isPeak:at:retentionDays:timeZone:)` prunes without persisting first, then persists once only if a new state is appended.

### Retention

`HistoryStore.defaultRetentionDays = 7`. When the display timezone is supplied, `prune(now:retentionDays:timeZone:)` cuts off at the start of the calendar day seven days ago; without a timezone it retains the previous fixed `now - 7 days` behavior. In both cases it keeps **one sample before the cutoff as an anchor** so the interval spanning the cutoff is still counted by the aggregator. Pruning runs on every record.

### Backfill

While the app is closed no samples are written, so the gap is repaired on the next launch and whenever the timezone changes. `HistoryStore.backfill(from:to:schedule:retentionDays:maxSamples:timeZone:)` recomputes the true transitions with the pure `PeakCalculator`, inserts the boundary samples plus a final sample at `now`, caps the addition to `defaultMaxBackfillSamples = 50`, and skips timestamps that already exist (idempotent).

### Aggregation

`HistoryAggregator.dailyDistribution(samples:now:days:timeZone:)` is pure. It builds exactly 7 calendar-day buckets ending with `now`'s day, turns consecutive samples into intervals (the earlier sample's state carries forward, the last interval runs to `now`), then clips and splits each interval at local day boundaries. DST-sized days (23h/25h) fall out naturally from the injected calendar and timezone. Each bucket also records whether it is the in-progress current day and the full calendar-day length, so `HistoryChartView` can normalize completed days to 100% while honestly leaving the current day partial. The result feeds `HistoryChartView` (Swift Charts).

### Reset

`HistoryStore.removeAll()` removes the `history.samples.v1` key. Settings exposes this as a confirmed **Clear History** action through `AppModel.clearHistory()`, which also reaggregates the chart. In tests and previews, `HistoryStore(defaults: nil)` (`HistoryStore.inMemory`) keeps everything in memory and writes nothing.
