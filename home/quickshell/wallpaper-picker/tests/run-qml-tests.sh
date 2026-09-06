#!/usr/bin/env bash
# Builds fixtures for, and runs, every headless QML test in this project:
# theme_test.qml, library_test.qml, applier_test.qml, shell_test.qml.
#
# Every one of those tests reads its inputs from WP_TEST_* environment
# variables (grep `Quickshell.env` in the test files themselves for the
# ground truth) and asserts specific values derived from them. If a variable
# is unset, Quickshell.env() returns an empty string and the test does NOT
# skip -- it fails with a confusing assertion mismatch that looks like a real
# component defect. This script is the only committed thing that sets them,
# so it is also the only way to run these tests meaningfully.
#
# Does NOT run tests/shell_test.sh. That script drives the REAL shell.qml
# under a live Wayland session and injects real key presses with wtype,
# grabbing your keyboard for its duration -- run it deliberately, by hand,
# not as part of an automated/headless suite.
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"   # wallpaper-picker/ (config root)

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fails=0
results=()

stub() { # stub <path> <body...>  -- write an executable script
  local path="$1"; shift
  { printf '#!/usr/bin/env bash\n'; printf '%s\n' "$@"; } > "$path"
  chmod +x "$path"
}

# ---------------------------------------------------------------------------
# Fixtures: theme_test.qml
#   WP_TEST_SCHEME  - full scheme, bare hex (no '#'), caelestia's format
#   WP_TEST_NOKEY   - valid JSON, no "colours" key at all
#   WP_TEST_PARTIAL - "colours" present, but missing keys (only background)
# ---------------------------------------------------------------------------
cat > "$WORK/scheme_good.json" <<'JSON'
{"colours": {
  "background": "131317",
  "surface": "131317",
  "surfaceContainer": "201f23",
  "onSurface": "e5e1e7",
  "outline": "918f9a",
  "primary": "c2c1ff"
}}
JSON
cat > "$WORK/scheme_nokey.json" <<'JSON'
{"notColours": true}
JSON
cat > "$WORK/scheme_partial.json" <<'JSON'
{"colours": {"background": "010203"}}
JSON

# ---------------------------------------------------------------------------
# Fixtures: library_test.qml
#   WP_TEST_ROOT       - dir/ alpha, files one.png + clip.mp4
#   WP_TEST_ROOT_SLASH - a second root, passed WITH a trailing slash
# ---------------------------------------------------------------------------
mkdir -p "$WORK/lib_root/alpha"
: > "$WORK/lib_root/one.png"
: > "$WORK/lib_root/clip.mp4"

mkdir -p "$WORK/lib_root_slash/child"

# ---------------------------------------------------------------------------
# Fixtures: applier_test.qml
#   WP_TEST_STUB  - appends its argv[1] to WP_TEST_LOG
#   WP_TEST_STUB2 - answers --current SLOWLY with a known path, logs other
#                   invocations to WP_TEST_LOG2
#   WP_TEST_LOG / WP_TEST_LOG2 - the log files those stubs write to
# ---------------------------------------------------------------------------
stub "$WORK/stub1.sh" \
  'printf '"'"'%s\n'"'"' "$1" >> "$WP_TEST_LOG"' \
  'exit 0'

stub "$WORK/stub2.sh" \
  'if [ "${1-}" = "--current" ]; then' \
  '  sleep 0.3' \
  '  echo "/tmp/original.png"' \
  '  exit 0' \
  'fi' \
  'printf '"'"'%s\n'"'"' "$1" >> "$WP_TEST_LOG2"' \
  'exit 0'

: > "$WORK/log1"
: > "$WORK/log2"

# ---------------------------------------------------------------------------
# Fixtures: shell_test.qml
#   WP_TEST_ROOT (shell variant) - two SAME-COUNT sibling folders A/ and B/,
#                                  each holding 1.png + 2.png
#   WP_TEST_OK / WP_TEST_FAIL / WP_TEST_SLOW - stubs that exit 0, exit 3, and
#                                  exit 0 after a long sleep, respectively
# ---------------------------------------------------------------------------
mkdir -p "$WORK/shell_root/A" "$WORK/shell_root/B"
: > "$WORK/shell_root/A/1.png"
: > "$WORK/shell_root/A/2.png"
: > "$WORK/shell_root/B/1.png"
: > "$WORK/shell_root/B/2.png"

stub "$WORK/ok.sh"   'exit 0'
stub "$WORK/fail.sh" 'exit 3'
stub "$WORK/slow.sh" 'sleep 0.8' 'exit 0'

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------
run_test() { # run_test <label> <qml file> <timeout seconds>
  local label="$1" qml="$2" secs="$3"
  echo "=== $label ==="
  local out rc
  out="$(QT_QPA_PLATFORM=offscreen timeout "$secs" quickshell -p "$DIR/$qml" 2>&1)"
  rc=$?
  echo "$out" | sed 's/^/  /'
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'ALL PASS'; then
    echo "--- $label: PASS ---"
    results+=("PASS $label")
  else
    echo "--- $label: FAIL (exit=$rc) ---"
    results+=("FAIL $label")
    fails=$((fails+1))
  fi
  echo
}

export WP_TEST_SCHEME="$WORK/scheme_good.json"
export WP_TEST_NOKEY="$WORK/scheme_nokey.json"
export WP_TEST_PARTIAL="$WORK/scheme_partial.json"
run_test "theme_test.qml" "theme_test.qml" 15

export WP_TEST_ROOT="$WORK/lib_root"
export WP_TEST_ROOT_SLASH="$WORK/lib_root_slash/"
run_test "library_test.qml" "library_test.qml" 15

export WP_TEST_STUB="$WORK/stub1.sh"
export WP_TEST_STUB2="$WORK/stub2.sh"
export WP_TEST_LOG="$WORK/log1"
export WP_TEST_LOG2="$WORK/log2"
run_test "applier_test.qml" "applier_test.qml" 15

export WP_TEST_ROOT="$WORK/shell_root"
export WP_TEST_OK="$WORK/ok.sh"
export WP_TEST_FAIL="$WORK/fail.sh"
export WP_TEST_SLOW="$WORK/slow.sh"
run_test "shell_test.qml" "shell_test.qml" 40

echo "==================================="
for r in "${results[@]}"; do echo "$r"; done
if [ "$fails" -eq 0 ]; then
  echo "ALL SUITES PASS"
  exit 0
else
  echo "SUITE FAILURES=$fails"
  exit 1
fi
