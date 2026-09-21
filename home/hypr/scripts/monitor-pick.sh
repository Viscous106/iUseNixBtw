#!/usr/bin/env bash
# monitor-pick.sh — pick an nwg-displays profile from rofi and apply it.
#
# Bound to SUPER+ALT+SHIFT+M. SUPER+ALT+M still opens the full nwg-displays GUI for
# editing; this is the two-keystroke path for switching between saved layouts.
#
# The pick is deliberately NOT sticky: the next hotplug or lid event re-runs
# monitor-auto.sh, which recomputes from state and overrides this choice.
#
# Known asymmetry (documented, not a bug): a GUI Apply from nwg-displays itself
# never touches $STATE, so a GUI-authored layout is sticky until some hotplug
# or lid event re-runs monitor-auto.sh. Likewise, picking a profile here that
# already matches the live state clears and rewrites $STATE but changes
# nothing on screen, and if no event ever follows, that pick is never
# superseded. Both are acceptable per the design's precedence rule.

set -uo pipefail

PROFILE_DIR="$HOME/.config/nwg-displays/profiles"
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-active-profile"

# Guard against a profile JSON with `active: false` on some output — e.g. a
# hand-edited or future-nwg-displays-version profile; disabling eDP-1 releases
# its CRTC and the reshuffle drops the external's DP link at the kernel level
# (see monitor-auto.sh's external_name() note and the design doc's "DP-link
# landmine" section). NOTE: this does NOT cover the GUI's own Active checkbox
# in nwg-displays 0.4.3 — that checkbox drives `outputs_activity`, while this
# JSON field is `db.active`, which `on_active_check_button_toggled` never
# touches. That route (Active unticked -> `disabled = true` written into
# monitors.lua) is instead covered by monitor-auto.sh's
# sanitize_disabled(), which heals it after the fact on every run.
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

# Never write $STATE here — only monitor-auto.sh's apply_profile() may do
# that, and only after monitor-verify.sh has OBSERVED the result. Profile DPMS
# is inert on this build (see monitor-auto.sh's AMENDED note), so
# nwg-displays-apply's exit code says nothing about whether DPMS actually
# landed where the profile wants it. Writing $STATE=<profile> here after a
# DPMS-losing pick (e.g. docked-extend while the lid is shut) would hit
# apply_profile's idempotence gate on the very next event and skip the
# dpms_set that would have repaired it — a permanently blanked panel. Clearing
# $STATE unconditionally is enough: it forces the next hotplug or lid event to
# recompute and re-apply from observed state, which is exactly what "picks are
# not sticky" already promises above.
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
