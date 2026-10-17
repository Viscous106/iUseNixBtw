#!/usr/bin/env bash
# Pick an nwg-displays profile from rofi (SUPER+ALT+SHIFT+M). Not sticky: the next
# MonitorAuto.sh run recomputes from state and overrides it.

set -uo pipefail

PROFILE_DIR="$HOME/.config/nwg-displays/profiles"
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-active-profile"

# Refuse profiles with an output marked inactive: disabling eDP-1 drops the
# external's DP link (see docs/design/nwg-displays-profile-driven-monitors.md).
profile_has_disabled_output() {
  local f="$PROFILE_DIR/$1.json" bad
  [ -f "$f" ] || return 1
  bad="$(jq -r '[.. | objects | select(has("active")) | select(.active == false)
                 | (.description // .name // "unknown")][0] // empty' "$f" 2>/dev/null)"
  if [ -n "$bad" ]; then
    notify-send -e -u critical "󰍹 Display" \
      "Refusing $1: output $bad has Active unticked" 2>/dev/null || true
    return 0
  fi
  return 1
}

mapfile -t profiles < <(find "$PROFILE_DIR" -maxdepth 1 -name '*.json' -printf '%f\n' \
                        2>/dev/null | sed 's/\.json$//' | sort)

if [ "${#profiles[@]}" -eq 0 ]; then
  notify-send -e -u critical "󰍹 Display" "No profiles in $PROFILE_DIR" 2>/dev/null
  exit 1
fi

choice="$(printf '%s\n' "${profiles[@]}" | rofi -dmenu -i -p "Display layout")"
[ -n "$choice" ] || exit 0

if profile_has_disabled_output "$choice"; then
  exit 1
fi

# Never write $STATE here: only MonitorAuto.sh may, after MonitorVerify.sh passes.
# Clearing it forces the next run to re-apply from observed state.
ok=0
if nwg-displays-apply -p "$choice" >/dev/null 2>&1; then
  notify-send -e -u low -t 1500 -h string:x-canonical-private-synchronous:monitor-auto \
    "󰍹 Display" "$choice" 2>/dev/null || true
else
  notify-send -e -u critical "󰍹 Display" "Failed to apply $choice" 2>/dev/null || true
  ok=1
fi
rm -f "$STATE"
exit "$ok"
