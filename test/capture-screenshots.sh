#!/usr/bin/env bash
#
# test/capture-screenshots.sh — render the English UI screenshots used in
# docs/screenshots/README.md (light + dark).
#
# macOS has no simulator, so the screenshots are rendered offscreen with
# SwiftUI's ImageRenderer by `CheapSeekTests/ScreenshotCaptureTests`. The test
# is gated by TEST_RUNNER_CAPTURE_SCREENSHOTS=1 and writes into
# SCREENSHOT_OUT_DIR; this script then copies the PNGs into
# docs/screenshots/light/ and docs/screenshots/dark/.
#
# Usage:
#   ./test/capture-screenshots.sh
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

PROJECT="${PROJECT:-CheapSeek.xcodeproj}"
SCHEME="${SCHEME:-CheapSeek}"
DESTINATION="${DESTINATION:-platform=macOS}"
OUT_DIR="$PROJECT_DIR/docs/screenshots"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cheapseek-screenshots.XXXXXX")"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found." >&2
  exit 1
fi

# Regenerate the project so the screenshot test is part of the target.
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

# xcodebuild forwards TEST_RUNNER_-prefixed variables to the test process with
# the prefix stripped, so the test sees CAPTURE_SCREENSHOTS and SCREENSHOT_OUT_DIR.
echo "Rendering screenshots into $TMP_DIR ..."
TEST_RUNNER_CAPTURE_SCREENSHOTS=1 \
TEST_RUNNER_SCREENSHOT_OUT_DIR="$TMP_DIR" \
SCREENSHOT_OUT_DIR="$TMP_DIR" \
xcodebuild test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:CheapSeekTests/ScreenshotCaptureTests \
  -resultBundlePath "$TMP_DIR/CheapSeekScreenshots.xcresult"

for mode in light dark; do
  if [[ ! -d "$TMP_DIR/$mode" ]]; then
    echo "No $mode screenshots were produced." >&2
    exit 1
  fi
  mkdir -p "$OUT_DIR/$mode"
  rm -f "$OUT_DIR/$mode"/*.png
  cp "$TMP_DIR/$mode/"*.png "$OUT_DIR/$mode/"
  echo "  $(ls "$OUT_DIR/$mode" | wc -l | tr -d ' ') images -> docs/screenshots/$mode"
done

echo "Done."
