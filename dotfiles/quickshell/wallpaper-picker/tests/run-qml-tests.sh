#!/usr/bin/env bash
# Runs the headless QML tests, setting the WP_TEST_* vars they need (unset ones fail confusingly, not skip).
# Not shell_test.sh: it drives the real shell.qml and grabs the keyboard, so run it by hand.
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

# Fixtures for theme_test.qml: full scheme (bare hex), no "colours" key, colours with only background.
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

# Fixtures for library_test.qml: a root with alpha/, one.png, clip.mp4, and one passed with a trailing slash.
mkdir -p "$WORK/lib_root/alpha"
: > "$WORK/lib_root/one.png"
: > "$WORK/lib_root/clip.mp4"

mkdir -p "$WORK/lib_root_slash/child"

# Fixtures for applier_test.qml: STUB logs argv[1]; STUB2 answers --current slowly; STUB3 answers
# --current/--current-audio (video with sound) only for eDP-1. Each logs to its WP_TEST_LOG{,2,3}.
stub "$WORK/stub1.sh" \
  'printf '"'"'%s\n'"'"' "$1" >> "$WP_TEST_LOG"' \
  'exit 0'

stub "$WORK/stub2.sh" \
  'if [ "${1-}" = "--current" ]; then' \
  '  sleep 0.3' \
  '  echo "/tmp/original.png"' \
  '  exit 0' \
  'fi' \
  'if [ "${1-}" = "--current-audio" ]; then echo off; exit 0; fi' \
  'printf '"'"'%s\n'"'"' "$1" >> "$WP_TEST_LOG2"' \
  'exit 0'

stub "$WORK/stub3.sh" \
  'case "$*" in' \
  '  "--current --output eDP-1")       echo "/tmp/original.mp4"; exit 0 ;;' \
  '  "--current-audio --output eDP-1") echo on; exit 0 ;;' \
  '  --current*)                       echo "/tmp/wrong-monitor.mp4"; exit 0 ;;' \
  'esac' \
  'printf '"'"'%s\n'"'"' "$*" >> "$WP_TEST_LOG3"' \
  'exit 0'

: > "$WORK/log1"
: > "$WORK/log2"
: > "$WORK/log3"

# Fixtures for shell_test.qml: same-count sibling folders A/ and B/, and stubs that exit 0, exit 3, or sleep.
mkdir -p "$WORK/shell_root/A" "$WORK/shell_root/B"
: > "$WORK/shell_root/A/1.png"
: > "$WORK/shell_root/A/2.png"
: > "$WORK/shell_root/B/1.png"
: > "$WORK/shell_root/B/2.png"

stub "$WORK/ok.sh"   'exit 0'
stub "$WORK/fail.sh" 'exit 3'
stub "$WORK/slow.sh" 'sleep 0.8' 'exit 0'

# Runner
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
export WP_TEST_STUB3="$WORK/stub3.sh"
export WP_TEST_LOG3="$WORK/log3"
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
