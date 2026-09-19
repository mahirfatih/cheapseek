# API Reference

## No network API

**CheapSeek makes no network calls.** There is no server, no account, no authentication, and no remote API. The peak/off-peak verdict is computed entirely on-device from the current UTC time, and history is stored locally (see [DATABASE.md](./DATABASE.md)).

The only system integrations are local macOS services:

| Service | Used for | Where |
| :--- | :--- | :--- |
| `UNUserNotificationCenter` | Scheduling local peak/off-peak alerts (no entitlement or network) | `NotificationManager.swift` |
| `SMAppService.mainApp` | Optional launch at login | `AppSettings.swift` |

## External data sources & links

Prices, peak windows, and the outbound links shown on the pricing screen are **bundled** in `CheapSeek/Configuration.plist` — they are never downloaded. The app only opens these URLs in the default browser when the user taps a link:

| Config key | URL | Purpose |
| :--- | :--- | :--- |
| `pricingURL` | https://api-docs.deepseek.com/quick_start/pricing/ | DeepSeek pricing page |
| `docsURL` | https://api-docs.deepseek.com/ | DeepSeek API documentation |
| `usageURL` | https://platform.deepseek.com/usage | DeepSeek API usage dashboard |

## Bundled configuration

`DeepSeekConfig` (`CheapSeek/DeepSeekConfig.swift`) loads and validates `Configuration.plist` at launch, falling back to built-in defaults if the file is missing or malformed:

| Key | Type | Meaning |
| :--- | :--- | :--- |
| `pricingURL` / `docsURL` / `usageURL` | `String` | Outbound links (above) |
| `weekdayOnly` | `Bool` | Peak windows apply Monday–Friday only |
| `offPeakFactor` | `Double` | Off-peak multiplier (0.5 = 50% off) |
| `peakWindows` | `[{startHour, endHour}]` | UTC half-open peak windows (`01:00–04:00`, `06:00–10:00`) |
| `models` | `[{id, name, inputCacheHit, inputCacheMiss, output}]` | Per-1M-token rates; each price has `peak` / `offPeak` |

When DeepSeek changes its rates, edit `CheapSeek/Configuration.plist`. `DeepSeekConfigTests` / `PricingConfigTests` validate the file, and the built-in `.fallback` keeps the app working if it cannot be read.
