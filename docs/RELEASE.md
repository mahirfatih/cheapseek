# Release Guide

How to ship a CheapSeek release. The project is generated from `project.yml` by
XcodeGen, so the Xcode project is never edited by hand. For local build setup,
see [DEVELOPMENT.md](./DEVELOPMENT.md); for Homebrew, see
[HOMEBREW.md](./HOMEBREW.md).

---

## Signing model (team id is never committed)

Signing follows the same pattern as the rest of the Labrus apps:

- `Config/Base.xcconfig` (committed) sets shared defaults and, at the end,
  `#include? "Local.xcconfig"`.
- `Config/Local.xcconfig` (gitignored) holds your Apple team id:
  ```
  cp Config/Local.xcconfig.example Config/Local.xcconfig
  # then set DEVELOPMENT_TEAM
  ```
- The generated `CheapSeek.xcodeproj` is **not** committed — run
  `xcodegen generate` after cloning.

A distributable build must be signed with a **Developer ID Application**
certificate (outside the App Store) and **notarized**.

### One-time notarization setup

Create an app-specific password at <https://appleid.apple.com> (Sign-In and
Security → App-Specific Passwords), then store it in the Keychain:

```sh
xcrun notarytool store-credentials "notary" \
  --apple-id <your-apple-id> --team-id <TEAM_ID> --password <app-specific-password>
```

`scripts/release.sh --notarize` uses the `notary` profile by default
(override with `--notary-profile`).

---

## 1. Bump the version

```sh
./scripts/bump-version.sh 1.0.1   # or: ./scripts/bump-version.sh 1.0.1 7
xcodegen generate
```

`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` live in `project.yml` and flow
into `CFBundleShortVersionString` / `CFBundleVersion`.

---

## 2. Build and package

```sh
./scripts/release.sh                     # signed Developer ID build + DMG
./scripts/release.sh --notarize          # also notarize and staple the DMG
./scripts/release.sh --notarize --publish
```

`release.sh` reads the team from `$DEVELOPMENT_TEAM`, `--team`, or
`Config/Local.xcconfig`, builds a Release `.app` into `build/`, and packages
`dist/CheapSeek-<version>.dmg` via [`scripts/make-dmg.sh`](../scripts/make-dmg.sh)
(app + `/Applications` symlink).

| Flag | Effect |
| :--- | :--- |
| `--unsigned` | Skip signing (`CODE_SIGNING_ALLOWED=NO`) |
| `--notarize` | Submit the DMG to Apple and staple it |
| `--publish` | Create/upload a GitHub Release with the DMG |
| `--no-dmg` | Stop after building the `.app` |
| `--team ID` / `--identity NAME` | Override the team / codesign identity |
| `--notary-profile NAME` | Keychain profile for `notarytool` (default `notary`) |

Unsigned smoke build (no certificate needed):

```sh
./scripts/release.sh --unsigned --output dist
```

---

## 3. Manual archive (optional)

```sh
xcodebuild archive -project CheapSeek.xcodeproj -scheme CheapSeek \
  -configuration Release -archivePath build/CheapSeek.xcarchive
```

Export with Developer ID using an untracked `ExportOptions.plist` (copy
[`ExportOptions.plist.example`](../ExportOptions.plist.example) and set
`teamID`):

```sh
xcodebuild -exportArchive -archivePath build/CheapSeek.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath build/export
```

---

## 4. Publish

```sh
./scripts/release.sh --notarize --publish
```

This uploads `dist/CheapSeek-<version>.dmg` to the GitHub Release tagged
`v<version>` (creating it if needed). All GitHub Actions workflows are
**manual-only** (`workflow_dispatch`).

---

## 5. Update Homebrew

```sh
./scripts/update-cask.sh 1.0.1
```

See [HOMEBREW.md](./HOMEBREW.md) for the tap, cask, and troubleshooting.

---

## Unsigned fallback (no Developer ID certificate yet)

If a Developer ID certificate is not available, you can still ship an unsigned DMG:

```sh
./scripts/release.sh --unsigned --publish
UNSIGNED=1 ./scripts/update-cask.sh <version>
```

`UNSIGNED=1` adds a Gatekeeper caveat to the cask (right-click → Open, or
`xattr -dr com.apple.quarantine /Applications/CheapSeek.app`). Replace the cask
once Developer ID signing is set up, so the caveat disappears.

> Developer ID Application certificates can only be created by the team's
> **Account Holder** (not by admins). See [HOMEBREW.md](./HOMEBREW.md) for the
> full Homebrew workflow.

---

## Unsigned CI artifact

`.github/workflows/release.yml` (manual `workflow_dispatch` only) builds an
**unsigned** Release app (`CODE_SIGNING_ALLOWED=NO`) and uploads it as the
`cheapseek-unsigned` artifact — for inspection/smoke only. Signing,
notarization, and publishing remain manual and local.
