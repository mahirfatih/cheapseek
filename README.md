# CheapSeek

> Never pay peak prices for DeepSeek API again.

**CheapSeek** is a tiny macOS menu bar app that tells you, at a glance, whether the DeepSeek API is currently in **peak** (expensive) or **off-peak** (cheap) pricing.

When it's cheap, you code. When it's expensive, you wait. Simple.

---

## ✨ Features

- 🟢 **Live status in your menu bar** — green `coding` when cheap, red `$` when expensive
- 🕐 **Timezone-aware** — peak hours computed in UTC, displayed in your local time (configurable timezone)
- 📅 **Today's full schedule** — see every peak/off-peak window for the day
- ⏳ **Next transition countdown** — "Next change in 3h 42m (to PEAK)"
- 🌗 **Light & dark mode** — follows your system appearance automatically
- 🌍 **Localized in 7 languages** — English, Türkçe, Deutsch, Español, Português, Français, Italiano
- ⚙️ **Settings** — language, timezone, launch at login, notifications toggle, refresh interval
- 🪶 **Minimal** — pure SwiftUI + Localize-Swift, release build under 1 MB
- 🔒 **No tracking, no telemetry, no network calls**

---

## 📦 Installation

### Build from source

```bash
xcodegen generate
xcodebuild -scheme CheapSeek -configuration Release build
```

### Homebrew

Not yet published. Coming soon.

---

## 🧪 Tests

```bash
xcodebuild test -scheme CheapSeek
```

Covers peak/off-peak logic, boundaries, weekends, and timezone-aware scheduling.
