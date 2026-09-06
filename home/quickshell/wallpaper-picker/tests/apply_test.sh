#!/usr/bin/env bash
# Tests apply.sh without touching the real desktop: AWWW_BIN/MPVPAPER_BIN are
# overridden with stubs that just log their arguments.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/../apply.sh"
fails=0

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export WP_STATE_DIR="$work/state"
export AWWW_BIN="$work/awww-stub"
export MPVPAPER_BIN="$work/mpvpaper-stub"
printf '#!/usr/bin/env bash\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
printf '#!/usr/bin/env bash\necho "mpvpaper $*" >> "%s/calls"\n' "$work" > "$MPVPAPER_BIN"
chmod +x "$AWWW_BIN" "$MPVPAPER_BIN"

img="$work/pic.png"; : > "$img"
vid="$work/clip.mp4"; : > "$vid"

check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  ok: $1"; else
    echo "  FAIL: $1"; echo "    expected: $2"; echo "    actual:   $3"; fails=$((fails+1)); fi
}

"$SUT" "$img" >/dev/null 2>&1
check "image records path"  "$img"   "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"
check "image records kind"  "image"  "$(cat "$WP_STATE_DIR/kind" 2>/dev/null)"
# Count 'awww img' specifically: apply_image() also runs 'awww query' to probe
# for a live daemon, so a stub logging every call records two lines.
check "image used awww img" "1"      "$(grep -c '^awww img' "$work/calls" 2>/dev/null || echo 0)"

"$SUT" "$vid" >/dev/null 2>&1
check "video records kind"  "video"  "$(cat "$WP_STATE_DIR/kind" 2>/dev/null)"
check "video used mpvpaper" "1"      "$(grep -c '^mpvpaper ' "$work/calls" 2>/dev/null || echo 0)"

check "--current prints path" "$vid" "$("$SUT" --current)"

: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1
check "restore reapplied video" "1" "$(grep -c '^mpvpaper ' "$work/calls" 2>/dev/null || echo 0)"

"$SUT" "$work/missing.png" >/dev/null 2>&1
check "missing file exits 1" "1" "$?"

# Test cold daemon case: awww query fails (non-zero) but img succeeds.
# Create daemon stub and a stub that fails on 'query' but succeeds on 'img'.
printf '#!/usr/bin/env bash\necho "awww-daemon" >> "%s/calls"\n' "$work" > "$AWWW_BIN-daemon"
chmod +x "$AWWW_BIN-daemon"
printf '#!/usr/bin/env bash\nif [ "$1" = query ]; then exit 1; fi\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"
: > "$work/calls"
"$SUT" "$img" >/dev/null 2>&1
check "cold daemon starts daemon" "1" "$(grep -c '^awww-daemon' "$work/calls" 2>/dev/null || echo 0)"
check "cold daemon applies image" "1" "$(grep -c '^awww img' "$work/calls" 2>/dev/null || echo 0)"

# Reset stubs to always succeed
rm -f "$AWWW_BIN-daemon"
printf '#!/usr/bin/env bash\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"

# Test unsupported extension exits 1 and writes no state
unsupported="$work/file.txt"
: > "$unsupported"
rm -f "$WP_STATE_DIR/current" "$WP_STATE_DIR/kind"
"$SUT" "$unsupported" >/dev/null 2>&1
check "unsupported exits 1" "1" "$?"
check "unsupported writes no state" "" "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"

# Test failing awww img exits 1 and writes no state
# Create stub that always fails on img
printf '#!/usr/bin/env bash\nif [ "$1" = img ]; then exit 1; fi\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"
rm -f "$WP_STATE_DIR/current" "$WP_STATE_DIR/kind"
"$SUT" "$img" >/dev/null 2>&1
check "failing awww img exits 1" "1" "$?"
check "failing awww img writes no state" "" "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"

# Test --restore with no state file at all: exits 0, writes no state, and
# still starts the awww daemon (regression: first login before anything has
# ever been applied must not leave a blank desktop).
rm -f "$WP_STATE_DIR/current" "$WP_STATE_DIR/kind"
printf '#!/usr/bin/env bash\necho "awww-daemon" >> "%s/calls"\n' "$work" > "$AWWW_BIN-daemon"
chmod +x "$AWWW_BIN-daemon"
printf '#!/usr/bin/env bash\nif [ "$1" = query ]; then exit 1; fi\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"
: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1
check "restore no-state exits 0"       "0"  "$?"
check "restore no-state writes no state" "" "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"
check "restore no-state starts daemon" "1"  "$(grep -c '^awww-daemon' "$work/calls" 2>/dev/null || echo 0)"

# Test --restore with a state file naming a path that no longer exists: same
# expectations, and the stale state is left untouched (not cleared, not
# reapplied).
printf '%s' "$work/gone.png" > "$WP_STATE_DIR/current"
: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1
check "restore stale-path exits 0"        "0"             "$?"
check "restore stale-path leaves state"   "$work/gone.png" "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"
check "restore stale-path starts daemon"  "1"             "$(grep -c '^awww-daemon' "$work/calls" 2>/dev/null || echo 0)"

rm -f "$AWWW_BIN-daemon"
printf '#!/usr/bin/env bash\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"

# Test --restore with valid state but a failing `awww img`: apply_path fails
# (die() inside apply_image would, pre-fix, kill the whole script before the
# trailing `exit 0` is ever reached), so this must still (a) fall back to
# starting the daemon, so awww's own cached image paints something instead of
# a blank desktop, and (b) exit 0 regardless -- a login hook must not fail
# loudly. The awww stub's `query` answer is gated on a marker file the daemon
# stub creates, so the daemon-start count stays deterministic: apply_image's
# own internal ensure_awww_daemon call starts it once, and the --restore
# fallback's ensure_awww_daemon call sees it already up and does not start it
# again.
printf '%s' "$img" > "$WP_STATE_DIR/current"
printf 'image' > "$WP_STATE_DIR/kind"
rm -f "$work/daemon-marker"
printf '#!/usr/bin/env bash\ntouch "%s/daemon-marker"\necho "awww-daemon" >> "%s/calls"\n' \
  "$work" "$work" > "$AWWW_BIN-daemon"
chmod +x "$AWWW_BIN-daemon"
printf '#!/usr/bin/env bash\nif [ "$1" = query ]; then [ -f "%s/daemon-marker" ] && exit 0 || exit 1; fi\nif [ "$1" = img ]; then exit 1; fi\necho "awww $*" >> "%s/calls"\n' \
  "$work" "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"
: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1
check "restore failing-apply exits 0"       "0" "$?"
check "restore failing-apply starts daemon" "1" "$(grep -c '^awww-daemon' "$work/calls" 2>/dev/null || echo 0)"

rm -f "$AWWW_BIN-daemon" "$work/daemon-marker"
printf '#!/usr/bin/env bash\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"

if [ "$fails" -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "FAILURES=$fails"; exit 1; fi
