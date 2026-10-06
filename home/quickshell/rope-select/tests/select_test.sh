#!/usr/bin/env bash
# Behavioural cover for select.sh, the slurp-compatible front end.
#
# quickshell and slurp are both replaced by stubs on PATH, so these run headless
# with no compositor and no real selector. What is being checked is the contract
# select.sh owes its callers (ScreenShot.sh, ScreenRecord.sh), which is exactly
# slurp's: geometry on stdout and exit 0, or a non-zero exit and nothing on
# stdout. Getting that wrong does not show up as an error -- it shows up as
# screenshots of the wrong region, or empty files in ~/Pictures/Screenshots.
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
SELECT="$DIR/select.sh"

fails=0
check() { if [ "$2" = "$3" ]; then echo "  ok: $1"; else
  echo "  FAIL: $1 (expected '$2', got '$3')"; fails=$((fails+1)); fi }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

stub() { # stub <dir> <name> <body...>
  mkdir -p "$1"
  { printf '#!/usr/bin/env bash\n'; printf '%s\n' "${@:3}"; } > "$1/$2"
  chmod +x "$1/$2"
}

# A quickshell that behaves like a completed selection: writes geometry to the
# file it was handed, exits 0.
mkdir -p "$WORK/ok"
stub "$WORK/ok" quickshell \
  'printf "%s\n" "$*" >> "$WORK_LOG"' \
  'printf "1930,20 100x50\n" > "$ROPE_SELECT_OUT"' \
  'exit 0'
stub "$WORK/ok" slurp 'echo "SLURP-WAS-CALLED"; exit 0'

# A quickshell that behaves like a cancel: writes the cancel sentinel, exits 1.
mkdir -p "$WORK/cancel"
stub "$WORK/cancel" quickshell 'printf "cancel\n" > "$ROPE_SELECT_OUT"; exit 1'
stub "$WORK/cancel" slurp 'echo "SLURP-WAS-CALLED"; exit 0'

# A quickshell that dies before deciding anything: nothing written at all.
mkdir -p "$WORK/crash"
stub "$WORK/crash" quickshell 'echo "boom" >&2; exit 3'
stub "$WORK/crash" slurp 'echo "7,8 9x10"; exit 0'

# No quickshell on PATH at all, only slurp.
mkdir -p "$WORK/noqs"
stub "$WORK/noqs" slurp 'echo "11,12 13x14"; exit 0'

# Neither available.
mkdir -p "$WORK/nothing"
stub "$WORK/nothing" true 'exit 0'

# A crashing quickshell AND a slurp the user then cancels.
mkdir -p "$WORK/bothcancel"
stub "$WORK/bothcancel" quickshell 'exit 3'
stub "$WORK/bothcancel" slurp 'exit 1'

# Only the utilities select.sh itself uses. Deliberately NOT the system
# profile: that carries the real quickshell and slurp, which would answer the
# "not installed" cases below and make them pass no matter what select.sh did.
mkdir -p "$WORK/base"
for b in bash mktemp head rm dirname; do
  ln -sf "$(command -v "$b")" "$WORK/base/$b"
done

run() { # run <stubdir> -- returns output, sets RC
  local d="$1"; shift
  out="$(PATH="$WORK/$d:$WORK/base" \
         WORK_LOG="$WORK/argv.log" \
         ROPE_SELECT_CONFIG_DIR="$DIR" \
         "$SELECT" "$@" 2>"$WORK/stderr")"
  RC=$?
}

echo "=== select.sh ==="

run ok
check "selection: geometry on stdout" "1930,20 100x50" "$out"
check "selection: exit 0"             "0"              "$RC"

# The whole point of the config dir argument -- a wrong one silently launches
# the user's DEFAULT quickshell config, i.e. their actual desktop shell.
check "selection: quickshell pointed at the config dir" "1" \
  "$(grep -qF -- "-p $DIR" "$WORK/argv.log" && echo 1 || echo 0)"

run cancel
check "cancel: nothing on stdout" ""  "$out"
check "cancel: exit 1"            "1" "$RC"
check "cancel: does NOT fall back to slurp" "1" \
  "$(grep -q 'SLURP-WAS-CALLED' <<<"$out" && echo 0 || echo 1)"

run crash
check "crash: falls back to slurp"      "7,8 9x10" "$out"
check "crash: exit 0 from the fallback" "0"        "$RC"

run noqs
check "no quickshell: falls back to slurp" "11,12 13x14" "$out"
check "no quickshell: exit 0"              "0"           "$RC"

run nothing
check "neither available: nothing on stdout" "" "$out"
check "neither available: non-zero exit"     "1" "$([ "$RC" -ne 0 ] && echo 1 || echo 0)"
check "neither available: says why on stderr" "1" \
  "$(grep -qi 'slurp\|quickshell' "$WORK/stderr" && echo 1 || echo 0)"

run bothcancel
check "crash then slurp cancelled: non-zero exit" "1" \
  "$([ "$RC" -ne 0 ] && echo 1 || echo 0)"
check "crash then slurp cancelled: no stdout" "" "$out"

# Temp files must not pile up in /tmp on every screenshot.
before="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'rope-select.*' 2>/dev/null | wc -l)"
run ok
after="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'rope-select.*' 2>/dev/null | wc -l)"
check "temp file cleaned up" "$before" "$after"

if [ "$fails" -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "FAILURES=$fails"; exit 1; fi
