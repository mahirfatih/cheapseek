#!/usr/bin/env bash
#
# scripts/bump-version.sh — update the app version in `project.yml`, the single
# source of truth for `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
#
# Usage:
#   ./scripts/bump-version.sh 1.1.0        # bump marketing version; build +1
#   ./scripts/bump-version.sh 1.1.0 7      # explicit version + build number
#
# Then run `xcodegen generate` to refresh CheapSeek.xcodeproj.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT_YML="project.yml"

VERSION="${1:-}"
BUILD="${2:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <marketing-version> [build-number]" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "'$VERSION' is not a semantic version (expected MAJOR.MINOR.PATCH)." >&2
  exit 1
fi

if [[ -z "$BUILD" ]]; then
  current="$(perl -ne 'print $1 if m/CURRENT_PROJECT_VERSION:\s*"?([0-9]+)"?/; exit if defined $1' "$PROJECT_YML")"
  BUILD=$(( ${current:-0} + 1 ))
fi

if [[ ! "$BUILD" =~ ^[0-9]+$ ]]; then
  echo "'$BUILD' is not a valid build number." >&2
  exit 1
fi

echo "Bumping CheapSeek to $VERSION ($BUILD)..."

perl -pi -e "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"$VERSION\"/g" "$PROJECT_YML"
perl -pi -e "s/CURRENT_PROJECT_VERSION: \"?[0-9]+\"?/CURRENT_PROJECT_VERSION: \"$BUILD\"/g" "$PROJECT_YML"

echo "Updated $PROJECT_YML."
echo "Run 'xcodegen generate' to refresh the Xcode project."
