#!/usr/bin/env bash
set -euo pipefail

PROJECT="CheapSeek.xcodeproj"
SCHEME="CheapSeek"
DESTINATION="platform=macOS"
LOGS_DIR="logs"
RESULTS_DIR="test/TestResults"
DO_GEN=1
COVERAGE=0
UI=0
LIST_ONLY=0

usage() {
  cat <<'EOF'
Usage: test/test.sh [options]

Generates the project and runs the CheapSeek tests via xcodebuild.

Options:
  --list                 Print the commands that would run, then exit.
  --no-gen               Skip `xcodegen generate`.
  --ui                   Include the UI tests (default: unit tests only).
  --coverage             Enable code coverage in the test action.
  --scheme NAME          Scheme to test (default: CheapSeek).
  --project PATH         Xcode project path (default: CheapSeek.xcodeproj).
  --destination DEST     Test destination (default: platform=macOS).
  --logs-dir DIR         Raw log output directory (default: logs).
  --results-dir DIR      .xcresult output directory (default: test/TestResults).
  -h, --help             Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) LIST_ONLY=1 ;;
    --no-gen) DO_GEN=0 ;;
    --ui) UI=1 ;;
    --coverage) COVERAGE=1 ;;
    --scheme) SCHEME="${2:?}"; shift ;;
    --project) PROJECT="${2:?}"; shift ;;
    --destination) DESTINATION="${2:?}"; shift ;;
    --logs-dir) LOGS_DIR="${2:?}"; shift ;;
    --results-dir) RESULTS_DIR="${2:?}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

GEN_CMD=(xcodegen generate)
TEST_CMD=(xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION")
[[ "$UI" == 0 ]] && TEST_CMD+=(-only-testing:CheapSeekTests)
[[ "$COVERAGE" == 1 ]] && TEST_CMD+=(-enableCodeCoverage YES)

if [[ "$LIST_ONLY" == 1 ]]; then
  [[ "$DO_GEN" == 1 ]] && printf '%s\n' "${GEN_CMD[*]}"
  printf '%s\n' "${TEST_CMD[*]}"
  exit 0
fi

mkdir -p "$LOGS_DIR" "$RESULTS_DIR"

STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
RESULT_PATH="$RESULTS_DIR/Test_${STAMP}.xcresult"
LOG_PATH="$LOGS_DIR/Test_${STAMP}.log"

TEST_CMD+=(-resultBundlePath "$RESULT_PATH")

if [[ "$DO_GEN" == 1 ]]; then
  "${GEN_CMD[@]}"
fi

set +e
"${TEST_CMD[@]}" 2>&1 | tee "$LOG_PATH"
STATUS=${PIPESTATUS[0]}
set -e

if [[ "$STATUS" -eq 0 ]]; then
  echo "Log:     $LOG_PATH"
  echo "Results: $RESULT_PATH"
  if [[ "$COVERAGE" == 1 ]]; then
    echo "Coverage:"
    xcrun xccov view --report "$RESULT_PATH" | grep -E "CheapSeek\.app|CheapSeekTests\.xctest" || true
  fi
else
  echo "Tests failed (exit $STATUS). Log: $LOG_PATH" >&2
fi

exit "$STATUS"
