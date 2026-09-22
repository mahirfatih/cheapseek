# Homebrew Guide

How CheapSeek is distributed through Homebrew, written for someone who has
never touched Homebrew before. For the full release process, see
[RELEASE.md](./RELEASE.md).

---

## 1. The three words you need

- **Homebrew** — a package manager for macOS. The command is `brew`.
- **Tap** — a GitHub repository that holds your own packages. `mahirfatih/tap`
  means the GitHub repo **`mahirfatih/homebrew-tap`**.
- **Cask** — a recipe (a Ruby `.rb` file) describing how to install a GUI app:
  where to download it from, how to verify it, and what to copy where.

The name mapping is mechanical:

```
brew install --cask  <user>/<tap>/<cask>
                          │        │
                          │        └─ GitHub repo: <user>/homebrew-<tap>
                          └─ GitHub user or org
```

So `mahirfatih/tap/cheapseek` → `https://github.com/mahirfatih/homebrew-tap`
→ file `Casks/cheapseek.rb`.

---

## 2. Install (what a user runs)

```sh
brew install --cask mahirfatih/tap/cheapseek
```

Upgrade and uninstall:

```sh
brew upgrade --cask cheapseek
brew uninstall --cask cheapseek        # keeps your preferences
brew uninstall --cask --zap cheapseek  # also removes preferences
```

---

## 3. The tap repository

The tap lives in a **separate** repository: `mahirfatih/homebrew-tap`.

```
homebrew-tap/
├── README.md
└── Casks/
    └── cheapseek.rb
```

The cask for the current release:

```ruby
cask "cheapseek" do
  version "1.0.0"
  sha256 "<sha256 of the DMG>"

  url "https://github.com/mahirfatih/cheapseek/releases/download/v#{version}/CheapSeek-#{version}.dmg"
  name "CheapSeek"
  desc "Menu bar app that shows when the DeepSeek API is off-peak"
  homepage "https://github.com/mahirfatih/cheapseek"

  depends_on macos: ">= :sonoma"

  app "CheapSeek.app"

  zap trash: [
    "~/Library/Preferences/com.labrus.CheapSeek.plist",
    "~/Library/Saved Application State/com.labrus.CheapSeek.savedState",
  ]
end
```

Line by line:

| Line | Meaning |
| :--- | :--- |
| `version` | The release version; `#{version}` reuses it in the URL. |
| `sha256` | Checksum of the exact DMG. `brew` refuses to install if it differs. |
| `url` | Where the DMG is downloaded from (a GitHub Release asset). |
| `name` / `desc` / `homepage` | Metadata shown by `brew info`. |
| `depends_on macos:` | Minimum macOS (Sonoma = 14). |
| `app "CheapSeek.app"` | Copies the app to `/Applications`. |
| `zap trash:` | Files `--zap` removes on uninstall. |

---

## 4. Publishing a new version

The DMG must be **signed with Developer ID and notarized** first (see the
prerequisites in [RELEASE.md](./RELEASE.md)).

```sh
# 1. Build, notarize, and upload the DMG to a GitHub Release
./scripts/release.sh --notarize --publish

# 2. Bump the cask to the new version (computes sha256, commits, pushes)
./scripts/update-cask.sh 1.0.1
```

`update-cask.sh` reads the DMG at `dist/CheapSeek-<version>.dmg` by default,
clones the tap into `../homebrew-tap` if needed, writes
`Casks/cheapseek.rb`, and pushes. Useful environment variables:

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `TAP_DIR` | `../homebrew-tap` | Local clone of the tap repo |
| `TAP_REPO` | `mahirfatih/homebrew-tap` | Remote to clone/push |
| `NO_PUSH` | `0` | `1` writes the cask without committing |

---

## 5. Validating the cask

```sh
brew tap mahirfatih/tap
brew audit --cask cheapseek
brew style --cask cheapseek
brew info --cask cheapseek
```

`brew audit` requires the tap to be added first (`brew tap`), which is why it
is not run in CI.

---

## 6. Troubleshooting

| Symptom | Cause / fix |
| :--- | :--- |
| `SHA256 mismatch` | The cask's `sha256` does not match the DMG. Re-run `scripts/update-cask.sh <version>`. |
| `Cask 'cheapseek' is unreadable` | Ruby syntax error in `cheapseek.rb`. Run `ruby -c Casks/cheapseek.rb`. |
| Gatekeeper: "damaged" / "unidentified developer" | The DMG is not notarized. Sign with Developer ID and notarize (`release.sh --notarize`). |
| `brew upgrade` says up to date but a new version exists | The cask `version` was not bumped; run `update-cask.sh`. |
| Stale download | `brew cleanup --prune=all` and retry. |

---

## 7. Türkçe özet (kısa)

- **Homebrew** = macOS paket yöneticisi (`brew`). **Tap** = kendi paketlerini
  koyduğun GitHub reposu. **Cask** = bir uygulamanın kurulum tarifi (`.rb`).
- `mahirfatih/tap/cheapseek` → GitHub'da **`mahirfatih/homebrew-tap`** reposu →
  `Casks/cheapseek.rb` dosyası.
- Kullanıcı kurar: `brew install --cask mahirfatih/tap/cheapseek`.
- Yeni sürüm yayınlarken:
  1. `./scripts/release.sh --notarize --publish` (DMG'yi imzalar, notarize eder,
     GitHub Release'e yükler)
  2. `./scripts/update-cask.sh 1.0.1` (sha256'yı hesaplar, cask'i günceller,
     tap reposuna push eder)
- DMG **notarize edilmiş** olmalı; yoksa Gatekeeper kullanıcıyı uyarır.
- Cask sözdizimini doğrula: `ruby -c Casks/cheapseek.rb`.

---

See also: [RELEASE.md](./RELEASE.md) · [../CONTRIBUTING.md](../CONTRIBUTING.md).
