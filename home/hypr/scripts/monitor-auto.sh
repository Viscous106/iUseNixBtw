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
  closed|open) flock -w 5 9 || exit 0 ;;
  *)           flock -n   9 || exit 0 ;;
esac

# --- Lua-parser call conventions --------------------------------------------
# This build uses the non-legacy (Lua) parser, so BOTH `hyprctl keyword` and the
# plain `hyprctl dispatch <name> <args>` forms are rejected — everything has to go
# through `hyprctl eval` against the same hl.* API used in lua/monitors.lua.
hy() { hyprctl eval "$1" >/dev/null; }
mon_set()    { hy "hl.monitor({ output = \"$1\", mode = \"$2\", position = \"$3\", scale = 1, disabled = false })"; }
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

# NOTE: we deliberately do NOT disable the internal panel for external-only.
# `hl.monitor({ disabled = true })` works, but on this NVIDIA + USB-C DP-alt-mode
# setup disabling eDP-1 releases its CRTC, and the resulting CRTC reshuffle drops
# the external's DP link entirely — the Dell goes to "disconnected" at the kernel
# level and only comes back on a physical replug. (In the aquamarine log:
# "eDP-1 is disabled, releasing crtc 392" -> hotplug -> "Connector DP-1 disconnected".)
# Blanking with dpms keeps its CRTC assigned, so there is no modeset churn and the
# external link stays up.
evacuate_int() {   # move everything off the internal panel, then blank it
  local ext="$1" ws
  for ws in $(hyprctl -j workspaces | jq -r --arg i "$INT" '.[] | select(.monitor == $i and .id > 0) | .id'); do
    ws_to_mon "$ws" "$ext"
  done
  focus_mon "$ext"
  dpms_set off "$INT"
  # Hyprland always keeps one workspace on an enabled monitor, so eDP-1 will still
  # hold an empty one. It is blanked and off to the side, which is harmless.
}

# Brief OSD naming the layout we just switched to.
notify_mode() {   # mode-label
  notify-send -e -u low -t 1500 -h string:x-canonical-private-synchronous:monitor-auto \
    "󰍹 Display" "$1" 2>/dev/null || true
}

EXT="$(external_name)"
mode=""

if [ -n "$EXT" ]; then
  # Both docked layouts share the same geometry, so these two mon_set calls are
  # no-ops on a lid toggle and the switch costs nothing but the dpms flip.
  mon_set "$INT" "$INT_MODE" "$INT_POS_DOCKED"
  mon_set "$EXT" "$EXT_MODE" "$EXT_POS"
  if lid_closed "$1"; then
    evacuate_int "$EXT"
    mode="External only"
  else
    dpms_set on "$INT"
    mode="Extended"
  fi
else
  if ! lid_closed "$1"; then
    dpms_set on "$INT"
    mon_set "$INT" "$INT_MODE" "$INT_POS_SOLO"
    mode="Laptop only"
  fi
  # no external + lid closed: leave displays as-is, there is nowhere to move to.
fi

if [ -n "$mode" ]; then
  notify_mode "$mode"
  sleep "$SETTLE"   # keep the lock held so our own hotplug echo is dropped
fi
