# Release Guide

The project is generated from `project.yml` by XcodeGen, so always regenerate before a release build. For local build setup, see [DEVELOPMENT.md](./DEVELOPMENT.md).

> **Signing prerequisite:** A distributable build must be signed with a **Developer ID Application** certificate (direct download) or an **Apple Distribution** certificate (Mac App Store). For local builds, set `DEVELOPMENT_TEAM` in `project.yml` first.

> **Unsigned artifact:** `.github/workflows/release.yml` (manual `workflow_dispatch` only) builds an **unsigned** Release app (`CODE_SIGNING_ALLOWED=NO`) and uploads it as the `cheapseek-unsigned` artifact. Developer ID signing, notarization, and App Store submission remain **manual** steps.

---

## 1. Bump the version

```bash
./scripts/bump-version.sh 1.1.0
xcodegen generate
```

`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` live in `project.yml` and flow into `CFBundleShortVersionString` / `CFBundleVersion`.

## 2. Build the Release app

```bash
xcodebuild build -project CheapSeek.xcodeproj -scheme CheapSeek \
  -configuration Release -derivedDataPath build
```

The app is produced at `build/Build/Products/Release/CheapSeek.app`; drag it into `/Applications` to run it.

## 3. Archive

```bash
xcodebuild archive -project CheapSeek.xcodeproj -scheme CheapSeek \
  -configuration Release -archivePath build/CheapSeek.xcarchive
```

This creates `build/CheapSeek.xcarchive` (the app is under `Products/Applications/`).

## 4. Distribute

- **Direct download (outside the App Store):** export with the Developer ID method, then notarize and staple:

  > `ExportOptions.plist` is **not** committed — create it with `method: developer-id` and your `teamID` before exporting.

  ```bash
  xcodebuild -exportArchive -archivePath build/CheapSeek.xcarchive \
    -exportOptionsPlist ExportOptions.plist -exportPath build/export
  ditto -c -k --keepParent build/export/CheapSeek.app build/CheapSeek.zip
  xcrun notarytool submit build/CheapSeek.zip --keychain-profile "notary" --wait
  xcrun stapler staple build/export/CheapSeek.app
  ```

- **Mac App Store / macOS TestFlight:** export the archive with `method: app-store` and upload via Xcode Organizer or Transporter.
