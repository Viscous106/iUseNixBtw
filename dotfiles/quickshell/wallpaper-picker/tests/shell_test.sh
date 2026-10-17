#!/usr/bin/env bash
# End-to-end proof of shell.qml's dismissal invariant:
#
#   "there is no state in which the user cannot dismiss this window
#    from the keyboard"
#
# The dangerous case is a revert that fails every time (awww down, or `original`
# naming a file that has since moved). The window holds WlrKeyboardFocus.Exclusive,
# so if a failing revert could keep cancelling the exit the user would be trapped
# with no way to reach a terminal.
#
# This runs the REAL shell.qml against a fake HOME whose apply.sh always fails,
# then presses Escape twice and asserts the process is gone well before the
# 3000 ms exitGrace backstop could have fired — i.e. it exited *because of* the
# second Escape, not because it timed out.
#
# Needs a live Wayland session (wtype). Run from anywhere.
set -uo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
check() { if [ "$2" = "$3" ]; then echo "  ok: $1"; else
  echo "  FAIL: $1 (expected '$2', got '$3')"; fails=$((fails+1)); fi }

command -v wtype >/dev/null 2>&1 || { echo "SKIP: wtype not available"; exit 0; }
[ -n "${WAYLAND_DISPLAY:-}" ] || { echo "SKIP: no WAYLAND_DISPLAY"; exit 0; }
: "${HYPRLAND_INSTANCE_SIGNATURE:=$(ls -t /run/user/$(id -u)/hypr/ 2>/dev/null | head -1)}"
export HYPRLAND_INSTANCE_SIGNATURE

FAKE="$(mktemp -d)"
trap 'rm -rf "$FAKE"' EXIT
mkdir -p "$FAKE/Pictures/wallpapers" "$FAKE/.config/quickshell/wallpaper-picker"
# Plain files at the library root, so a preview is scheduled with no keypress at
# all: `previewed` becomes true on its own and Escape takes the revert path.
: > "$FAKE/Pictures/wallpapers/1.png"
: > "$FAKE/Pictures/wallpapers/2.png"

cat > "$FAKE/.config/quickshell/wallpaper-picker/apply.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HOME/calls"
case "${1-}" in
  # --current must succeed, or Applier never records an `original` and revert()
  # would quietly do nothing — which is not the case under test.
  --current) echo "$HOME/Pictures/wallpapers/2.png"; exit 0 ;;
  *)         exit 7 ;;
esac
STUB
chmod +x "$FAKE/.config/quickshell/wallpaper-picker/apply.sh"

HOME="$FAKE" quickshell -p "$DIR" > "$FAKE/run.log" 2>&1 &
pid=$!
sleep 2

check "shell still running before Escape" "1" "$(kill -0 $pid 2>/dev/null && echo 1 || echo 0)"
check "preview was attempted"             "1" \
  "$(grep -qF '/Pictures/wallpapers/1.png' "$FAKE/calls" 2>/dev/null && echo 1 || echo 0)"

wtype -k Escape                 # first Escape: starts the close, revert fails
sleep 0.4
check "revert was attempted and failed" "1" \
  "$(grep -qF '/Pictures/wallpapers/2.png' "$FAKE/calls" 2>/dev/null && echo 1 || echo 0)"

wtype -k Escape                 # second Escape: must exit unconditionally
gone=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  kill -0 $pid 2>/dev/null || { gone=1; break; }
  sleep 0.1
done
check "second Escape exits within 1s (backstop is 3s)" "1" "$gone"

kill $pid 2>/dev/null; wait $pid 2>/dev/null
if [ "$fails" -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "FAILURES=$fails"; exit 1; fi
