#!/usr/bin/env bash
#
# scripts/bump-version.sh — bump the app version in project.yml (canonical source).
#
# project.yml holds MARKETING_VERSION (CFBundleShortVersionString) and
# CURRENT_PROJECT_VERSION (CFBundleVersion). Every Info.plist references them via
# $(MARKETING_VERSION) / $(CURRENT_PROJECT_VERSION), so project.yml is the only
# place to edit.
#
# Usage:
#   ./scripts/bump-version.sh <marketing-version> [build-number]
#
# Examples:
#   ./scripts/bump-version.sh 1.0.2        # set 1.0.2, auto-increment build
#   ./scripts/bump-version.sh 1.1.0 5      # set 1.1.0 / build 5
#
# After bumping, regenerate the project:
#   xcodegen generate
#
set -euo pipefail

PROJECT_YML="${PROJECT_YML:-project.yml}"

usage() {
  sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

NEW_VERSION="$1"
NEW_BUILD="${2:-}"

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must be semver (MAJOR.MINOR.PATCH), got '$NEW_VERSION'" >&2
  exit 1
fi

if [[ ! -f "$PROJECT_YML" ]]; then
  echo "error: $PROJECT_YML not found (run from the repo root)" >&2
  exit 1
fi

CURRENT_MARKETING="$(grep -E '^[[:space:]]*MARKETING_VERSION:' "$PROJECT_YML" | head -n1 | sed -E 's/.*"([^"]*)".*/\1/')"
CURRENT_BUILD="$(grep -E '^[[:space:]]*CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -n1 | sed -E 's/.*"([^"]*)".*/\1/')"

if [[ -z "$CURRENT_MARKETING" || -z "$CURRENT_BUILD" ]]; then
  echo "error: could not read MARKETING_VERSION / CURRENT_PROJECT_VERSION from $PROJECT_YML" >&2
  exit 1
fi

if [[ -z "$NEW_BUILD" ]]; then
  NEW_BUILD="$((CURRENT_BUILD + 1))"
fi

if [[ ! "$NEW_BUILD" =~ ^[0-9]+$ ]]; then
  echo "error: build number must be an integer, got '$NEW_BUILD'" >&2
  exit 1
fi

# Portable in-place sed (BSD/macOS vs GNU).
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(sed -i)
else
  SED_INPLACE=(sed -i '')
fi

"${SED_INPLACE[@]}" -E "s/^([[:space:]]*MARKETING_VERSION: ).*/\1\"${NEW_VERSION}\"/" "$PROJECT_YML"
"${SED_INPLACE[@]}" -E "s/^([[:space:]]*CURRENT_PROJECT_VERSION: ).*/\1\"${NEW_BUILD}\"/" "$PROJECT_YML"

echo "Bumped version: $CURRENT_MARKETING ($CURRENT_BUILD) -> $NEW_VERSION ($NEW_BUILD)"
echo "Next: xcodegen generate"
