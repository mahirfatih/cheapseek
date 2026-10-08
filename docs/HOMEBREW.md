# Homebrew Guide

How CheapSeek is distributed through Homebrew, written for someone who has
never touched Homebrew before. For the full release process, see
[RELEASE.md](./RELEASE.md).

**Contents**

1. [Key terms](#1-key-terms)
2. [Install, upgrade, uninstall](#2-install-upgrade-uninstall)
3. [The tap repository](#3-the-tap-repository)
4. [Publishing a new version](#4-publishing-a-new-version)
5. [Validating the cask](#5-validating-the-cask)
6. [Troubleshooting](#6-troubleshooting)
7. [Türkçe özet](#7-türkçe-özet)

---

## 1. Key terms

| Term | Meaning |
| :--- | :--- |
| **Homebrew** | A package manager for macOS. The command is `brew`. |
| **Tap** | A GitHub repository that holds your own packages. `mahirfatih/tap` means the repo **`mahirfatih/homebrew-tap`**. |
| **Cask** | A Ruby (`.rb`) recipe describing how to install a GUI app: where to download it, how to verify it, and what to copy where. |

The name mapping is mechanical (Homebrew adds the `homebrew-` prefix for you):

```
brew install --cask  <user>/<tap>/<cask>
                       │      │      │
                       │      │      └─ file: Casks/<cask>.rb
                       │      └──────── repo: <user>/homebrew-<tap>
                       └─────────────── GitHub user or org
```

So `mahirfatih/tap/cheapseek` → `https://github.com/mahirfatih/homebrew-tap`
→ `Casks/cheapseek.rb`.

---

## 2. Install, upgrade, uninstall

**Install** (what a user runs, one line):

```sh
brew install --cask mahirfatih/tap/cheapseek
```

Or in two steps, which also lets `brew upgrade` find updates by short name:

```sh
brew tap mahirfatih/tap
brew install --cask cheapseek
```

**Upgrade and uninstall:**

```sh
brew upgrade --cask cheapseek
brew uninstall --cask cheapseek        # keeps your preferences
brew uninstall --cask --zap cheapseek  # also removes preferences
```

> **Requirements:** macOS 14 (Sonoma) or newer.

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
  sha256 "<sha256 of the DMG>"   # placeholder: update-cask.sh fills in the real value

  url "https://github.com/mahirfatih/cheapseek/releases/download/v#{version}/CheapSeek-#{version}.dmg"
  name "CheapSeek"
  desc "Menu bar app that shows when the DeepSeek API is off-peak"
  homepage "https://github.com/mahirfatih/cheapseek"

  livecheck do
    url :url
    strategy :github_latest
  end

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
| `livecheck` | Lets `brew livecheck` detect new GitHub releases automatically. |
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

> **Order matters.** Run step 1 first. If the cask is pushed before the
> Release asset exists, users get a 404 on install.

`update-cask.sh` reads the DMG at `dist/CheapSeek-<version>.dmg` by default,
clones the tap into `../homebrew-tap` if needed, writes `Casks/cheapseek.rb`,
and pushes. Useful environment variables:

| Variable | Default | Purpose |
| :--- | :--- | :--- |
| `TAP_DIR` | `../homebrew-tap` | Local clone of the tap repo |
| `TAP_REPO` | `mahirfatih/homebrew-tap` | Remote to clone/push |
| `NO_PUSH` | `0` | `1` writes the cask without committing |

**Release checklist**

- [ ] DMG is signed and notarized (`xcrun stapler validate dist/CheapSeek-1.0.1.dmg`)
- [ ] GitHub Release `v1.0.1` exists and contains the DMG
- [ ] `./scripts/update-cask.sh 1.0.1` finished and pushed
- [ ] `brew audit` and `brew style` pass (section 5)
- [ ] Test install on a clean machine or account

**Checking the checksum by hand** (optional, useful when debugging):

```sh
shasum -a 256 dist/CheapSeek-1.0.1.dmg
```

---

## 5. Validating the cask

```sh
brew tap mahirfatih/tap
brew trust --tap mahirfatih/tap
brew audit --cask --strict --online mahirfatih/tap/cheapseek
brew style --cask mahirfatih/tap/cheapseek
brew info --cask cheapseek
```

`brew audit` requires the tap to be added first (`brew tap`), which is why it
is not run in CI.

Quick syntax check without Homebrew:

```sh
ruby -c Casks/cheapseek.rb
```

---

## 6. Troubleshooting

| Symptom | Cause / fix |
| :--- | :--- |
| `SHA256 mismatch` | The cask's `sha256` does not match the DMG. Re-run `scripts/update-cask.sh <version>`. |
| `Cask 'cheapseek' is unreadable` | Ruby syntax error in `cheapseek.rb`. Run `ruby -c Casks/cheapseek.rb`. |
| Gatekeeper: "damaged" / "unidentified developer" | The DMG is not notarized. Sign with Developer ID and notarize (`release.sh --notarize`). Check with `spctl -a -vv -t install dist/CheapSeek-<version>.dmg`. |
| `brew upgrade` says up to date but a new version exists | The cask `version` was not bumped; run `update-cask.sh`. Then `brew update` on the user's side. |
| `404` while downloading | The GitHub Release or its DMG asset does not exist yet (or the tag name differs from `v<version>`). |
| `Cask 'cheapseek' is not available` | The tap is not added or has a typo. Run `brew tap mahirfatih/tap`. |
| Stale download | `brew cleanup --prune=all` and retry. |

---

## 7. Türkçe özet

**Temel kavramlar**

- **Homebrew** = macOS paket yöneticisi (`brew`).
- **Tap** = kendi paketlerini koyduğun GitHub reposu.
- **Cask** = bir uygulamanın kurulum tarifi (`.rb` dosyası).
- `mahirfatih/tap/cheapseek` → GitHub'da **`mahirfatih/homebrew-tap`** reposu →
  `Casks/cheapseek.rb` dosyası.

**Kullanıcı için**

```sh
brew install --cask mahirfatih/tap/cheapseek   # kur
brew upgrade --cask cheapseek                  # güncelle
brew uninstall --cask --zap cheapseek          # tercihlerle birlikte kaldır
```

**Yeni sürüm yayınlarken (sırayla)**

1. `./scripts/release.sh --notarize --publish` — DMG'yi imzalar, notarize eder,
   GitHub Release'e yükler.
2. `./scripts/update-cask.sh 1.0.1` — sha256'yı hesaplar, cask'i günceller, tap
   reposuna push eder.

**Dikkat edilecekler**

- Sıra önemli: önce Release yüklenmeli, sonra cask güncellenmeli; aksi hâlde
  kullanıcılar 404 alır.
- DMG **notarize edilmiş** olmalı; yoksa Gatekeeper kullanıcıyı uyarır.
- Cask sözdizimini doğrula: `ruby -c Casks/cheapseek.rb`.
- Sorun giderme için yukarıdaki [Troubleshooting](#6-troubleshooting) tablosuna bak.

---

See also: [RELEASE.md](./RELEASE.md) · [../CONTRIBUTING.md](../CONTRIBUTING.md).
