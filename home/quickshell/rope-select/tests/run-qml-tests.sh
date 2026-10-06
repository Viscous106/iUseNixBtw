#!/usr/bin/env bash
# Builds fixtures for, and runs, every headless QML test in this project:
# selection_test.qml, rope_test.qml, theme_test.qml.
#
# theme_test.qml reads its inputs from RS_TEST_* environment variables. If one
# is unset, Quickshell.env() returns an empty string and the test does NOT
# skip -- it fails with a confusing mismatch that looks like a real component
# defect. This script is the only committed thing that sets them.
#
# Does NOT cover Geom.qml or shell.qml. Both root at PanelWindow, which needs a
# live Wayland compositor with layer-shell ("No PanelWindow backend loaded"
# under QT_QPA_PLATFORM=offscreen). That is exactly why all the maths lives in
# Selection.qml instead -- what is left in Geom is layout and painting, which
# has to be checked by eye on a real session.
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"   # rope-select/ (config root)

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fails=0
results=()

cat > "$WORK/scheme_good.json" <<'JSON'
{"colours": {"surface": "131317", "primary": "c2c1ff"}}
JSON
cat > "$WORK/scheme_nokey.json" <<'JSON'
{"notColours": true}
JSON
cat > "$WORK/scheme_partial.json" <<'JSON'
{"colours": {"surface": "010203"}}
JSON

run_test() { # run_test <label> <qml file> <timeout seconds>
  local label="$1" qml="$2" secs="$3"
  echo "=== $label ==="
  local out rc
  out="$(QT_QPA_PLATFORM=offscreen timeout "$secs" quickshell -p "$DIR/$qml" 2>&1)"
  rc=$?
  # The runtime-dir errors quickshell prints when XDG_RUNTIME_DIR is not
  # writable are noise here; the tests themselves do not need it.
  echo "$out" | grep -v 'quickshell\.\(paths\|logging\|ipc\|tooling\)' | sed 's/^/  /'
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

run_test "selection_test.qml" "selection_test.qml" 15
run_test "rope_test.qml"      "rope_test.qml"      20

export RS_TEST_SCHEME="$WORK/scheme_good.json"
export RS_TEST_NOKEY="$WORK/scheme_nokey.json"
export RS_TEST_PARTIAL="$WORK/scheme_partial.json"
run_test "theme_test.qml" "theme_test.qml" 15

echo "==================================="
for r in "${results[@]}"; do echo "$r"; done
if [ "$fails" -eq 0 ]; then
  echo "ALL SUITES PASS"
  exit 0
else
  echo "SUITE FAILURES=$fails"
  exit 1
fi
