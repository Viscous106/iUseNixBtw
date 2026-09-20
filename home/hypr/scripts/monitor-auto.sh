#!/usr/bin/env bash
# Automatic monitor management for Hyprland — event-driven, no manual picker.
#
# Invoked from lua/monitors.lua on: hyprland.start, monitor.added, monitor.removed,
# and on the Lid Switch (open/close) binds. Each call re-reads the full state
# (is an external connected? is the lid closed?) and applies the right layout.
#
#   external connected + lid open    -> EXTEND         (laptop left, external right)
#   external connected + lid closed  -> EXTERNAL ONLY  (laptop blanked, external primary)
#   no external        + lid open    -> LAPTOP ONLY
#   no external        + lid closed  -> nothing (nowhere to move the session to)
#
# Optional arg: "closed" | "open" forces the lid state instead of reading the ACPI
# sensor. The Lid Switch binds pass it, because /proc/acpi can still report the
# previous state at the instant Hyprland fires the switch event.

INT="eDP-1"                 # internal laptop panel
INT_MODE="1920x1080@144"
EXT_MODE="preferred"        # never hardcode a mode: an invalid one silently
                            # falls back to 1024x768 (bit us with @100 on the LG)
SETTLE=2                    # seconds to hold the lock after applying (see below)

# --- geometry: why the laptop lives at a NEGATIVE x -------------------------
# The external is pinned at 0x0 and the laptop sits immediately to its LEFT, at
# -1920x0. That keeps the physical arrangement (laptop left, monitor right) while
# making the two regions disjoint no matter which one is placed first.
#
# The obvious layout — laptop at 0x0, external at 1920x0 — cannot be reached from
# "external only" (external 0..3840, laptop 3840..5760) without passing through an
# overlap: move the laptop first and it lands inside the external, move the
# external first and it swallows the laptop. Hyprland notices that intermediate
# state and latches the "Monitor eDP-1 overlaps with other monitor(s)" warning.
#
# With the external fixed at 0x0 the coordinates never have to change when
# toggling docked layouts, so switching is a pure dpms flip: no modeset, no
# overlap, and near-instant instead of several seconds of mode changes.
EXT_POS="0x0"
INT_POS_DOCKED="-1920x0"    # left of the external; disjoint from it by construction
INT_POS_SOLO="0x0"          # nothing else on screen, so the origin is free

# --- reentrancy guard -------------------------------------------------------
# Reconfiguring an output makes Hyprland emit monitor.removed / monitor.added,
# which re-invokes this very script. Without a guard that echo re-runs the layout
# and instantly reverts what was just applied. So: hold a lock across the apply
# plus a short settle window, and drop hotplug-triggered runs that land inside it.
# Lid runs carry explicit user intent, so they wait for the lock instead.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/hypr-monitor-auto.lock"
exec 9>"$LOCK"
case "$1" in
  closed|open|rotate) flock -w 5 9 || exit 0 ;;
  *)                  flock -n   9 || exit 0 ;;
esac

# --- Lua-parser call conventions --------------------------------------------
# This build uses the non-legacy (Lua) parser, so BOTH `hyprctl keyword` and the
# plain `hyprctl dispatch <name> <args>` forms are rejected — everything has to go
# through `hyprctl eval` against the same hl.* API used in lua/monitors.lua.
hy() { hyprctl eval "$1" >/dev/null; }

# --- self-healing sanitiser for the disabled= landmine ----------------------
# A GUI Apply with Active unticked writes `disabled = true` (Lua) / `,disable`
# (conf) into ~/.config/hypr/monitors.lua / monitors.conf. Since Task 3 those
# files are require()'d / read on every run, so the poisoned state survives a
# hyprland.lua reload, a full reboot, AND the physical replug that is supposed
# to recover the DP link — nwg-displays' own safety net does not help here:
# its confirm-or-revert dialog cannot render when no output is left to click
# on, and its revert path deliberately does not reload. This runs on every
# invocation of this script, in particular hyprland.start — exactly when a
# poisoned file would have just been loaded — and heals it: strip the
# directive from disk, and re-enable the output live so this boot does not
# stay bricked waiting for the next GUI Apply to fix the file for real.
sanitize_disabled() {
  local f found=0 out
  for f in "$HOME/.config/hypr/monitors.lua" "$HOME/.config/hypr/monitors.conf"; do
    [ -f "$f" ] || continue
    if grep -qE '(disabled\s*=\s*true|,disable\b)' "$f"; then
      found=1
      sed -i --follow-symlinks -E 's/disabled\s*=\s*true/disabled = false/g; s/,disable\b//g' "$f"
    fi
  done
  [ "$found" = 1 ] || return 0
  # An output that `hyprctl -j monitors all` reports but the plain (non-all)
  # list omits is disabled — the same all-vs-plain distinction
  # check_int_not_disabled in monitor-verify.sh relies on. Reuse it here
  # instead of guessing at a JSON field name.
  for out in $(comm -23 \
                 <(hyprctl -j monitors all | jq -r '.[].name' | sort) \
                 <(hyprctl -j monitors     | jq -r '.[].name' | sort)); do
    hy "hl.monitor({ output = \"$out\", disabled = false })"
  done
  notify-send -e -u critical "󰍹 Display" \
    "Removed a disabled= directive from the generated monitor config and re-enabled the output live — re-author that profile in nwg-displays with Active ticked" \
    2>/dev/null || true
}
sanitize_disabled

# scripts/auto-rotate.sh owns the internal panel's rotation and records the
# current transform in $XDG_RUNTIME_DIR/hypr-rotation. Re-applying the panel
# without it would silently un-rotate a folded tablet on every lid event and
# every HDMI hotplug. Externals are never rotated.
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

# hl.dsp.dpms is a minefield: the POSITIONAL form respects `mode` but ignores the
# monitor and blanks every output, while the TABLE form targets one monitor but
# IGNORES `mode` and simply TOGGLES. So the table form is the only usable one, and
# it has to be driven against the observed state. A single check-then-toggle is
# still not enough, because a mon_set on the same output flips dpms back on
# asynchronously and the state we read can be stale — so verify and retry.
dpms_is_on() { hyprctl -j monitors all | jq -e --arg m "$1" 'any(.[]; .name == $m and .dpmsStatus)' >/dev/null 2>&1; }
dpms_set() {   # want(on|off)  monitor
  local want="$1" m="$2" i
  for i in 1 2 3 4 5; do
    if [ "$want" = on ]; then dpms_is_on "$m" && return 0; else dpms_is_on "$m" || return 0; fi
    hy "hl.dispatch(hl.dsp.dpms{ monitor = \"$m\" })"   # ignores mode; toggles
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

# The external is whatever is plugged in that is not the internal panel — do NOT
# hardcode an output name. This box has seen the LG on HDMI-A-1 and the Dell
# S2725QC on DP-1; hardcoding HDMI-A-1 made every "am I docked?" check fail, so
# the lid-closed branch never ran and the layout never switched.
external_name() {
  hyprctl -j monitors all | jq -r --arg i "$INT" 'map(select(.name != $i)) | .[0].name // empty'
}

# --- profile selection -----------------------------------------------------
# Geometry now lives in nwg-displays profiles, authored through the GUI and
# applied with `nwg-displays-apply -p`. This script only decides WHICH profile
# the current state calls for. If the profile is missing (unrecognised external,
# or profiles not yet authored) it falls back to the hardcoded geometry below,
# so auto-extend still works on unknown hardware.
PROFILE_DIR="$HOME/.config/nwg-displays/profiles"
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-active-profile"

have_profile() { [ -f "$PROFILE_DIR/$1.json" ]; }

# Guard against a profile JSON with `active: false` on some output — e.g. a
# hand-edited or future-nwg-displays-version profile; disabling eDP-1 releases
# its CRTC and the reshuffle drops the external's DP link at the kernel level
# (see external_name()'s note and the design doc's "DP-link landmine"
# section). NOTE: this does NOT cover the GUI's own Active checkbox in
# nwg-displays 0.4.3 — that checkbox drives `outputs_activity`, while this
# JSON field is `db.active`, which `on_active_check_button_toggled` never
# touches, so unticking Active in the GUI does not change what this guard
# reads. That route (Active unticked -> `disabled = true` written into
# monitors.lua/monitors.conf) is instead covered by sanitize_disabled() above,
# which heals it after the fact on every run.
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

# monitor-verify.sh lives beside this script; resolve it relative to our own
# directory rather than hardcoding a path.
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# AMENDED 2026-09-20: profile DPMS is inert on this build. nwg-displays drives
# DPMS with plain `hyprctl dispatch dpms ...`, which the non-legacy Lua parser
# rejects outright (verified live: `hyprctl dispatch dpms on eDP-1` ->
# "')' expected near 'on'"), and nwg-displays never reads the IPC reply, so it
# reports success regardless. Profiles therefore own GEOMETRY ONLY; this script
# keeps driving DPMS itself via dpms_set, exactly as it always has.
#
# Idempotence gate. `nwg-displays-apply` ends in `hyprctl reload`, which can
# re-enter this script; re-applying the same profile would oscillate. Comparing
# against the last applied name breaks the cycle regardless of whether
# hyprland.start re-fires on reload (see Task 1 in the plan). The gate is only
# armed on OBSERVED success — a failed apply, a rejected profile, or a failed
# verify must NOT poison $STATE, or every later event would return early
# without ever retrying.
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
  # The profile's transform is a static value captured when the profile was
  # authored, while scripts/auto-rotate.sh writes the LIVE rotation to
  # $XDG_RUNTIME_DIR/hypr-rotation at runtime — so a stale profile transform
  # would clobber a folded-tablet rotation on every profile apply. Re-assert it
  # here, and BEFORE dpms_set: per the dpms_set note above, an hl.monitor call
  # on an output flips its dpms back on asynchronously, so doing this after
  # dpms_set would re-light a panel that was just blanked and fail
  # verification forever. Order matters here — do not swap these two lines.
  t="$(int_transform)"
  [ "$t" != 0 ] && hy "hl.monitor({ output = \"$INT\", transform = $t })"
  dpms_set "$dpms_want" "$INT"
  if "$SELF_DIR/monitor-verify.sh" "$name" >/dev/null 2>&1; then
    printf '%s' "$name" > "$STATE"
  else
    notify-send -e -u critical "󰍹 Display" "$name applied but failed verification" 2>/dev/null || true
    rm -f "$STATE"   # do not let a stale prior profile suppress the retry
    return 1
  fi
}

# Move every workspace off the internal panel. Split out of the old
# evacuate_int(): apply_profile() drives the dpms flip exactly once, after the
# profile geometry is applied — doing it here too would double-toggle
# (hl.dsp.dpms ignores `mode` and simply toggles).
move_ws_off_int() {
  local ext="$1" ws
  for ws in $(hyprctl -j workspaces | jq -r --arg i "$INT" \
                '.[] | select(.monitor == $i and .id > 0) | .id'); do
    ws_to_mon "$ws" "$ext"
  done
  focus_mon "$ext"
}

# Fallback: the pre-profile hardcoded path. Applied live via mon_set()
# (hl.monitor), but it does NOT persist across a reload: nwg-displays'
# generated ~/.config/hypr/monitors.lua is still require()'d after this
# module runs, so a reload re-applies whatever that file last held over this
# fallback's runtime geometry. That's fine — the fallback's whole purpose is
# "some sane geometry now, on unrecognised hardware", not a persisted layout.
fallback_layout() {
  local ext="$1" closed="$2"
  if [ -n "$ext" ]; then
    mon_set "$INT" "$INT_MODE" "$INT_POS_DOCKED"
    mon_set "$ext" "$EXT_MODE" "$EXT_POS"
    if [ "$closed" = yes ]; then
      move_ws_off_int "$ext"; dpms_set off "$INT"
    else
      dpms_set on "$INT"
    fi
  else
    dpms_set on "$INT"
    mon_set "$INT" "$INT_MODE" "$INT_POS_SOLO"
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
    # Verify-gating makes failure a routine path now, not an exotic one: hold
    # the settle window on this path too, or the flock releases straight into
    # hyprctl reload's hotplug echo, which re-enters, re-applies, re-fails.
    notify_mode "$label (failed)"
  fi
  sleep "$SETTLE"
else
  fallback_layout "$EXT" "$CLOSED"
  rm -f "$STATE"          # fallback geometry is not a profile
  notify_mode "$label (fallback)"
  sleep "$SETTLE"
fi
