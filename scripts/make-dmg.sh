#!/usr/bin/env bash
#
# scripts/make-dmg.sh — package a built CheapSeek.app into a drag-to-install DMG.
#
# The DMG contains the app plus an /Applications symlink, which is the standard
# macOS layout: the user opens the DMG and drags the app onto Applications.
#
# Usage:
#   scripts/make-dmg.sh <path/to/CheapSeek.app> [output-dir]
#
# Prints the created DMG path on the last line.
#
set -euo pipefail

APP="${1:-}"
OUT_DIR="${2:-dist}"

if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "Usage: $0 <path/to/CheapSeek.app> [output-dir]" >&2
  exit 1
fi

NAME="CheapSeek"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo "0.0.0")"
DMG="$OUT_DIR/${NAME}-${VERSION}.dmg"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/cheapseek-dmg.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

mkdir -p "$OUT_DIR"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"

hdiutil create \
  -volname "${NAME} ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG"

echo "$DMG"
