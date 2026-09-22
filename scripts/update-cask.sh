#!/usr/bin/env bash
#
# scripts/update-cask.sh — refresh the Homebrew cask for a new CheapSeek release.
#
# Writes Casks/cheapseek.rb in a local clone of the tap repo with the given
# version and the DMG's sha256, then commits and pushes it.
#
# Usage:
#   scripts/update-cask.sh <version> [path/to/CheapSeek-<version>.dmg]
#
# Environment:
#   TAP_DIR   local clone of the tap repo   (default: ../homebrew-tap)
#   TAP_REPO  GitHub repo for the tap       (default: mahirfatih/homebrew-tap)
#   NO_PUSH   set to 1 to write the cask without committing/pushing
#   UNSIGNED  set to 1 to add a Gatekeeper caveat (unsigned/unnotarized DMG)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version> [path/to/CheapSeek-<version>.dmg]" >&2
  exit 1
fi

DMG="${2:-$ROOT/dist/CheapSeek-$VERSION.dmg}"
TAP_DIR="${TAP_DIR:-$ROOT/../homebrew-tap}"
TAP_REPO="${TAP_REPO:-mahirfatih/homebrew-tap}"
CASK_DIR="$TAP_DIR/Casks"
CASK="$CASK_DIR/cheapseek.rb"

if [[ ! -f "$DMG" ]]; then
  echo "DMG not found: $DMG" >&2
  echo "Run scripts/release.sh first, or pass the DMG path explicitly." >&2
  exit 1
fi

SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "Updating cask to $VERSION (sha256 $SHA)"

if [[ ! -d "$TAP_DIR/.git" ]]; then
  echo "Cloning $TAP_REPO into $TAP_DIR ..."
  gh repo clone "$TAP_REPO" "$TAP_DIR"
fi

mkdir -p "$CASK_DIR"

CAVEATS=""
if [[ "${UNSIGNED:-0}" == "1" ]]; then
  CAVEATS=$'\n  caveats <<~EOS\n    CheapSeek is not notarized yet. On first launch, right-click the app and\n    choose Open, or run:\n      xattr -dr com.apple.quarantine /Applications/CheapSeek.app\n  EOS\n'
fi

cat > "$CASK" <<RUBY
cask "cheapseek" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/mahirfatih/cheapseek/releases/download/v#{version}/CheapSeek-#{version}.dmg"
  name "CheapSeek"
  desc "Menu bar app that shows when the DeepSeek API is off-peak"
  homepage "https://github.com/mahirfatih/cheapseek"

  depends_on macos: :sonoma

  app "CheapSeek.app"
${CAVEATS}
  zap trash: [
    "~/Library/Preferences/com.labrus.CheapSeek.plist",
    "~/Library/Saved Application State/com.labrus.CheapSeek.savedState",
  ]
end
RUBY

echo "Wrote $CASK"

if [[ "${NO_PUSH:-0}" == "1" ]]; then
  echo "NO_PUSH=1 set; skipping commit/push."
  exit 0
fi

git -C "$TAP_DIR" add Casks/cheapseek.rb
if git -C "$TAP_DIR" diff --cached --quiet; then
  echo "Cask already up to date; nothing to commit."
else
  git -C "$TAP_DIR" commit -m "cheapseek $VERSION"
  git -C "$TAP_DIR" push
  echo "Pushed to $TAP_REPO."
fi
