# CheapSeek

> Never pay peak prices for DeepSeek API again.

**CheapSeek** is a tiny macOS menu bar app that tells you, at a glance, whether the DeepSeek API is currently in **peak** (expensive) or **off-peak** (cheap) pricing.

When it's cheap, you code. When it's expensive, you wait. Simple.

---

## ✨ Features

- 🟢 **Live status in your menu bar** — green `coding` when cheap, red `$` when expensive
- 🕐 **Timezone-aware** — peak hours computed in UTC, displayed in your local time
- 📅 **Today's full schedule** — see every peak/off-peak window for the day
- ⏳ **Next transition countdown** — "Next change in 3h 42m (to PEAK)"
- 🌗 **Light & dark mode** — follows your system appearance automatically
- 🔔 **Peak warnings** (optional) — get notified before prices go up
- 🪶 **Zero dependencies** — pure SwiftUI, under 1 MB
- 🔒 **No tracking, no telemetry, no network calls**

---

## 📸 Screenshot

![CheapSeek menu bar popup](docs/screenshot.png)

*The popup shows the current status, today's schedule, and the next transition.*

---

## 📦 Installation

### Homebrew (recommended)

```bash
brew install --cask cheapseek
