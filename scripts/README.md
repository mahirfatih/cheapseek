# Scripts

Small helpers for versioning, release, and distribution. Run them from the repository root.

| Script | Purpose |
| :--- | :--- |
| [`bump-version.sh`](./bump-version.sh) `<version> [build]` | Set `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` (the single source); run `xcodegen generate` after. |
| [`release.sh`](./release.sh) `[--unsigned] [--notarize] [--publish]` | Build a Release app and package it — signs with `Config/Local.xcconfig`, optionally notarizes and publishes a GitHub release. |
| [`make-dmg.sh`](./make-dmg.sh) `<app> [output-dir]` | Package a built `.app` into a drag-to-install DMG. |
| [`update-cask.sh`](./update-cask.sh) `<version> [dmg]` | Refresh the Homebrew cask (`sha256`) for a release. |

See [docs/RELEASE.md](../docs/RELEASE.md), [docs/HOMEBREW.md](../docs/HOMEBREW.md), and [docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md) for the full workflows.
