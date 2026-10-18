#!/usr/bin/env bash
# Monitor layout from lid/plug state; run only by Refresh.sh (SUPER+ALT+R), since
# automatic hooks kept reverting nwg-displays layouts. Arg closed|open forces lid state.

INT="eDP-1"
INT_MODE="1920x1080@144"   # also in AutoRotate.sh; see int_rule()
EXT_MODE="preferred"        # an invalid hardcoded mode silently falls back to 1024x768
SETTLE=2                    # seconds to hold the lock after applying

# Positions stay non-negative (nwg-displays can't show negatives) and never move:
# eDP-1 at 0x0, external at 1920x0, so docked switches are a pure dpms flip.
EXT_POS="1920x0"
INT_POS_DOCKED="0x0"
INT_POS_SOLO="0x0"

# Reconfiguring emits monitor add/remove, which can re-invoke this script; hold a
# lock through a settle window. Lid runs wait for it, others drop.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/hypr-monitor-auto.lock"
exec 9>"$LOCK"
case "$1" in
  closed|open|rotate) flock -w 5 9 || exit 0 ;;
  *)                  flock -n   9 || exit 0 ;;
esac

# The Lua parser rejects `hyprctl keyword` and plain `dispatch`; everything uses eval.
hy() { hyprctl eval "$1" >/dev/null; }

# Partial panel rules must restate INT_MODE: nwg-displays names the panel "desc:...",
# so an "eDP-1" rule starts fresh at "preferred" (60 Hz, not 144).
# Every rule sets scale = 1: without it Hyprland auto-scales the 15.6" panel to 1.5.
int_rule() { hy "hl.monitor({ output = \"$INT\", mode = \"$INT_MODE\", scale = 1, $1 })"; }

# A GUI Apply with Active unticked writes `disabled = true` into monitors.lua, which
# kills the DP link and survives reboots; strip it and re-enable outputs live.
sanitize_disabled() {
  local f="$HOME/.config/hypr/monitors.lua" out
  [ -f "$f" ] || return 0
  grep -qE 'disabled\s*=\s*true' "$f" || return 0
  sed -i --follow-symlinks -E 's/disabled\s*=\s*true/disabled = false/g' "$f"
  # Re-enabled panel rules carry no mode, so add INT_MODE. Edit the resolved path:
  # perl -i would replace the symlink with a plain file.
  INT="$INT" INT_MODE="$INT_MODE" \
  INT_DESC="$(hyprctl -j monitors all | jq -r --arg m "$INT" '.[] | select(.name == $m) | .description')" \
    perl -0pi -e 's/(hl\.monitor\(\{\s*output\s*=\s*"(?:\Q$ENV{INT}\E|desc:\Q$ENV{INT_DESC}\E)",)(?![^}]*\bmode\s*=)/$1\n    mode = "$ENV{INT_MODE}",/g; s/(hl\.monitor\(\{\s*output\s*=\s*"(?:\Q$ENV{INT}\E|desc:\Q$ENV{INT_DESC}\E)",)(?![^}]*\bscale\s*=)/$1\n    scale = 1,/g' \
    "$(readlink -f "$f")"
  # Outputs in `monitors all` but not the plain list are disabled.
  for out in $(comm -23 \
                 <(hyprctl -j monitors all | jq -r '.[].name' | sort) \
                 <(hyprctl -j monitors     | jq -r '.[].name' | sort)); do
    if [ "$out" = "$INT" ]; then
      int_rule "disabled = false"
    else
      hy "hl.monitor({ output = \"$out\", scale = 1, disabled = false })"
    fi
  done
  notify-send -e -u critical "󰍹 Display" \
    "Removed a disabled= directive from the generated monitor config and re-enabled the output live — re-author that profile in nwg-displays with Active ticked" \
    2>/dev/null || true
}
sanitize_disabled

# AutoRotate.sh owns panel rotation; re-assert it so a layout change doesn't un-rotate.
int_transform() {
  local t
  t=$(cat "${XDG_RUNTIME_DIR:-/tmp}/hypr-rotation" 2>/dev/null)
  case "$t" in 0|1|2|3|4|5|6|7) echo "$t" ;; *) echo 0 ;; esac
}
mon_set() {
  local t=0
  [ "$1" = "$INT" ] && t=$(int_transform)
  hy "hl.monitor({ output = \"$1\", mode = \"$2\", position = \"$3\", scale = 1, disabled = false, transform = $t })"
}
focus_mon()  { hy "hl.dispatch(hl.dsp.focus{ monitor = \"$1\" })"; }
ws_to_mon()  { hy "hl.dispatch(hl.dsp.workspace.move{ workspace = \"$1\", monitor = \"$2\" })"; }

# Only the table form of hl.dsp.dpms targets one monitor, and it just toggles, so
# drive it against observed state and retry (mon_set re-lights dpms asynchronously).
dpms_is_on() { hyprctl -j monitors all | jq -e --arg m "$1" 'any(.[]; .name == $m and .dpmsStatus)' >/dev/null 2>&1; }
dpms_set() {   # want(on|off)  monitor
  local want="$1" m="$2" i
  for i in 1 2 3 4 5; do
    if [ "$want" = on ]; then dpms_is_on "$m" && return 0; else dpms_is_on "$m" || return 0; fi
    hy "hl.dispatch(hl.dsp.dpms{ monitor = \"$m\" })"
    sleep 0.4
  done
  return 1
}

lid_closed() {
  case "$1" in
    closed) return 0 ;;
    open)   return 1 ;;
  esac
  local f
  for f in /proc/acpi/button/lid/*/state; do
    [ -e "$f" ] || continue
    grep -qi closed "$f" && return 0
    return 1
  done
  return 1                  # no lid sensor -> treat as open
}

# The external is whatever isn't eDP-1: it has been on HDMI-A-1 and DP-1.
external_name() {
  hyprctl -j monitors all | jq -r --arg i "$INT" 'map(select(.name != $i)) | .[0].name // empty'
}

# Geometry lives in nwg-displays profiles; this picks which one. No profile ->
# hardcoded fallback geometry, so unknown externals still extend.
PROFILE_DIR="$HOME/.config/nwg-displays/profiles"
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-active-profile"

have_profile() { [ -f "$PROFILE_DIR/$1.json" ]; }

# Refuse profiles with an output marked inactive (disabling eDP-1 drops the DP link).
# The GUI's Active checkbox isn't covered here; sanitize_disabled() heals that case.
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

# MonitorVerify.sh lives beside this script.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Profiles own geometry only: nwg-displays' DPMS uses plain `dispatch`, which the Lua
# parser rejects. $STATE stops reload re-entry; set only on verified success.
apply_profile() {   # apply_profile <profile-name> <dpms-want: on|off>
  local name="$1" dpms_want="$2" t
  if [ "$(cat "$STATE" 2>/dev/null)" = "$name" ]; then
    return 0
  fi
  if profile_has_disabled_output "$name"; then
    return 1
  fi
  if ! nwg-displays-apply -p "$name" >/dev/null 2>&1; then
    notify-send -e -u critical "󰍹 Display" "nwg-displays-apply failed for $name" 2>/dev/null || true
    return 1
  fi
  # Re-assert live rotation over the profile's static one, BEFORE dpms_set: an
  # hl.monitor call re-lights dpms asynchronously. Do not swap these lines.
  t="$(int_transform)"
  [ "$t" != 0 ] && int_rule "transform = $t"
  dpms_set "$dpms_want" "$INT"
  if "$SELF_DIR/MonitorVerify.sh" "$name" >/dev/null 2>&1; then
    printf '%s' "$name" > "$STATE"
  else
    notify-send -e -u critical "󰍹 Display" "$name applied but failed verification" 2>/dev/null || true
    rm -f "$STATE"   # do not let a stale prior profile suppress the retry
    return 1
  fi
}

# dpms is flipped once in apply_profile(); doing it here too would double-toggle.
move_ws_off_int() {
  local ext="$1" ws
  for ws in $(hyprctl -j workspaces | jq -r --arg i "$INT" \
                '.[] | select(.monitor == $i and .id > 0) | .id'); do
    ws_to_mon "$ws" "$ext"
  done
  focus_mon "$ext"
}

# Does monitors.lua already have a rule for this output (by connector or desc:)?
lua_covers() {   # lua_covers <connector>
  local f="$HOME/.config/hypr/monitors.lua" desc
  [ -f "$f" ] || return 1
  grep -qF "output = \"$1\"" "$f" && return 0
  desc="$(hyprctl -j monitors all | jq -r --arg m "$1" '.[] | select(.name == $m) | .description')"
  [ -n "$desc" ] && grep -qF "output = \"desc:$desc\"" "$f"
}

# No profile: if monitors.lua already places every output, keep that geometry;
# hardcoded positions are only for outputs it doesn't know.
fallback_layout() {
  local ext="$1" closed="$2" t
  if [ -n "$ext" ]; then
    if lua_covers "$INT" && lua_covers "$ext"; then
      # monitors.lua carries a static transform; re-assert the live rotation.
      t="$(int_transform)"
      [ "$t" != 0 ] && int_rule "transform = $t"
    else
      mon_set "$INT" "$INT_MODE" "$INT_POS_DOCKED"
      mon_set "$ext" "$EXT_MODE" "$EXT_POS"
    fi
    if [ "$closed" = yes ]; then
      move_ws_off_int "$ext"; dpms_set off "$INT"
    else
      dpms_set on "$INT"
    fi
  else
    dpms_set on "$INT"
    if lua_covers "$INT"; then
      t="$(int_transform)"
      [ "$t" != 0 ] && int_rule "transform = $t"
    else
      mon_set "$INT" "$INT_MODE" "$INT_POS_SOLO"
    fi
  fi
}

notify_mode() {   # mode-label
  notify-send -e -u low -t 1500 -h string:x-canonical-private-synchronous:monitor-auto \
    "󰍹 Display" "$1" 2>/dev/null || true
}

EXT="$(external_name)"
if lid_closed "$1"; then CLOSED=yes; else CLOSED=no; fi

if [ -n "$EXT" ]; then
  if [ "$CLOSED" = yes ]; then want=docked-external; label="External only"
  else                          want=docked-extend;  label="Extended"; fi
else
  # no external + lid closed: nowhere to move the session to, leave it alone.
  [ "$CLOSED" = yes ] && exit 0
  want=laptop-only; label="Laptop only"
fi

dpms_want=on
[ "$want" = docked-external ] && dpms_want=off

if have_profile "$want"; then
  # Workspaces must leave the panel before the profile blanks it.
  [ "$want" = docked-external ] && move_ws_off_int "$EXT"
  if apply_profile "$want" "$dpms_want"; then
    notify_mode "$label"
  else
    # Hold the settle window on failure too, or reload's hotplug echo re-enters and re-fails.
    notify_mode "$label (failed)"
  fi
  sleep "$SETTLE"
else
  fallback_layout "$EXT" "$CLOSED"
  rm -f "$STATE"          # fallback geometry is not a profile
  notify_mode "$label (fallback)"
  sleep "$SETTLE"
fi
