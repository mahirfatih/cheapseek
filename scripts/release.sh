#!/usr/bin/env bash
#
# scripts/release.sh — build a Release app and package it for distribution.
#
# The signing team is never committed: it is read from $DEVELOPMENT_TEAM, the
# --team flag, or the gitignored Config/Local.xcconfig. Credentials for
# notarization live in the macOS Keychain (see `notarytool store-credentials`).
#
# Usage:
#   scripts/release.sh                     # signed Developer ID build + DMG
#   scripts/release.sh --unsigned          # ad-hoc / unsigned build
#   scripts/release.sh --notarize --publish
#   scripts/release.sh --team ABCDE12345 --identity "Developer ID Application"
#
# Options:
#   --team ID            Apple Developer team id (default: $DEVELOPMENT_TEAM
#                        or Config/Local.xcconfig)
#   --identity NAME      Codesign identity (default: "Developer ID Application")
#   --notary-profile N   notarytool keychain profile (default: "notary")
#   --output DIR         DMG output directory (default: dist)
#   --unsigned           Disable code signing (CODE_SIGNING_ALLOWED=NO)
#   --notarize           Submit the DMG to Apple and staple it
#   --publish            Create/upload a GitHub release with the DMG
#   --no-dmg             Stop after building the .app
#   -h, --help           Show this help
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="${PROJECT:-CheapSeek.xcodeproj}"
SCHEME="${SCHEME:-CheapSeek}"
CONFIG="Release"
OUT_DIR="${OUT_DIR:-dist}"
IDENTITY="${IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"
TEAM="${DEVELOPMENT_TEAM:-}"
UNSIGNED=0
NOTARIZE=0
PUBLISH=0
DO_DMG=1

usage() {
  cat <<'EOF'
Usage: scripts/release.sh [options]

Build a Release app and package it for distribution. The signing team is read
from $DEVELOPMENT_TEAM, --team, or the gitignored Config/Local.xcconfig.

Options:
  --team ID            Apple Developer team id (default: $DEVELOPMENT_TEAM
                       or Config/Local.xcconfig)
  --identity NAME      Codesign identity (default: "Developer ID Application")
  --notary-profile N   notarytool keychain profile (default: "notary")
  --output DIR         DMG output directory (default: dist)
  --unsigned           Disable code signing (CODE_SIGNING_ALLOWED=NO)
  --notarize           Submit the DMG to Apple and staple it
  --publish            Create/upload a GitHub release with the DMG
  --no-dmg             Stop after building the .app
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team) TEAM="${2:?--team needs a value}"; shift ;;
    --identity) IDENTITY="${2:?--identity needs a value}"; shift ;;
    --notary-profile) NOTARY_PROFILE="${2:?--notary-profile needs a value}"; shift ;;
    --output) OUT_DIR="${2:?--output needs a value}"; shift ;;
    --unsigned) UNSIGNED=1 ;;
    --notarize) NOTARIZE=1 ;;
    --publish) PUBLISH=1 ;;
    --no-dmg) DO_DMG=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode." >&2
  exit 1
fi

VERSION="$(perl -ne 'print $1 if /MARKETING_VERSION:\s*"?([0-9.]+)"?/; exit if defined $1' project.yml)"
BUILD="$(perl -ne 'print $1 if /CURRENT_PROJECT_VERSION:\s*"?([0-9]+)"?/; exit if defined $1' project.yml)"
: "${VERSION:?Could not read MARKETING_VERSION from project.yml}"

if [[ -z "$TEAM" && -f Config/Local.xcconfig ]]; then
  TEAM="$(perl -ne 'print $1 if /^\s*DEVELOPMENT_TEAM\s*=\s*(\S+)/' Config/Local.xcconfig || true)"
fi

if [[ "$UNSIGNED" == 0 ]]; then
  : "${TEAM:?No signing team. Set DEVELOPMENT_TEAM, pass --team, or create Config/Local.xcconfig (see Config/Local.xcconfig.example). Use --unsigned to skip signing.}"
fi
if [[ "$NOTARIZE" == 1 && "$UNSIGNED" == 1 ]]; then
  echo "--notarize cannot be combined with --unsigned." >&2
  exit 1
fi
if [[ "$PUBLISH" == 1 && "$DO_DMG" == 0 ]]; then
  echo "--publish requires a DMG (remove --no-dmg)." >&2
  exit 1
fi

echo "Releasing CheapSeek $VERSION ($BUILD)"

command -v xcodegen >/dev/null 2>&1 && xcodegen generate

BUILD_ARGS=(-project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG"
  -destination 'platform=macOS' -derivedDataPath build)

if [[ "$UNSIGNED" == 1 ]]; then
  echo "Building unsigned Release..."
  xcodebuild "${BUILD_ARGS[@]}" CODE_SIGNING_ALLOWED=NO build
else
  echo "Building signed Release (team $TEAM, identity '$IDENTITY')..."
  xcodebuild "${BUILD_ARGS[@]}" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM" \
    ENABLE_HARDENED_RUNTIME=YES \
    build
fi

APP="build/Build/Products/$CONFIG/CheapSeek.app"
if [[ ! -d "$APP" ]]; then
  echo "Built app not found at $APP" >&2
  exit 1
fi

if [[ "$UNSIGNED" == 0 ]]; then
  echo "Verifying signature..."
  codesign --verify --deep --strict --verbose=2 "$APP"
  codesign -dv --verbose=4 "$APP" 2>&1 | grep -E "Authority|TeamIdentifier" || true
fi

DMG=""
if [[ "$DO_DMG" == 1 ]]; then
  DMG="$("$ROOT/scripts/make-dmg.sh" "$APP" "$OUT_DIR" | tail -n1)"
  echo "Created $DMG"
  if [[ "$UNSIGNED" == 0 ]]; then
    codesign --force --sign "$IDENTITY" --timestamp "$DMG"
  fi
fi

if [[ "$NOTARIZE" == 1 ]]; then
  echo "Notarizing with profile '$NOTARY_PROFILE' (this waits for Apple)..."
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi

if [[ "$PUBLISH" == 1 ]]; then
  TAG="v$VERSION"
  if gh release view "$TAG" >/dev/null 2>&1; then
    echo "Release $TAG exists; uploading $DMG..."
    gh release upload "$TAG" "$DMG" --clobber
  else
    echo "Creating GitHub release $TAG..."
    gh release create "$TAG" "$DMG" --title "CheapSeek $VERSION" --generate-notes
  fi
fi

echo "Done."
