#!/usr/bin/env bash
# Runs the headless QML tests, setting the RS_TEST_* vars they need (unset ones fail confusingly, not skip).
# Geom.qml and shell.qml need a live compositor (PanelWindow), so check those by eye.
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
