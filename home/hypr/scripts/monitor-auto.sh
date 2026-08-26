#!/usr/bin/env bash
# Automatic monitor management for Hyprland — event-driven, no manual picker.
#
# Invoked from lua/monitors.lua on: hyprland.start, monitor.added, monitor.removed,
# and on the Lid Switch (open/close) binds. Each call re-reads the full state
# (is the external connected? is the lid closed?) and applies the right layout.
#
#   external connected + lid open    -> EXTEND        (laptop left, external right)
#   external connected + lid closed  -> EXTERNAL ONLY  (laptop off, external primary)
#   no external        + lid open    -> LAPTOP ONLY
#   no external        + lid closed  -> nothing (logind suspends an undocked laptop)

INT="eDP-1"                 # internal laptop panel
EXT="HDMI-A-1"              # external output
INT_MODE="1920x1080@144"
EXT_MODE="1920x1080@60"     # LG FULL HD max is 75Hz; @100 is invalid and silently falls back to 1024x768

lid_closed() {
  local f
  for f in /proc/acpi/button/lid/*/state; do
    [ -e "$f" ] || continue
    grep -qi closed "$f" && return 0
    return 1
  done
  return 1                  # no lid sensor -> treat as open
}

ext_connected() {
  hyprctl -j monitors all | jq -e --arg e "$EXT" 'any(.[]; .name == $e)' >/dev/null 2>&1
}

# This is a Lua-config Hyprland build: `hyprctl keyword monitor` is rejected by the
# non-legacy parser ("Use eval."). Runtime monitor changes must go through
# `hyprctl eval` calling the same hl.monitor{} API used in lua/monitors.lua.
mon_set() {   # output  mode  position  (also clears a prior disabled state)
  hyprctl eval "hl.monitor({ output = \"$1\", mode = \"$2\", position = \"$3\", scale = 1, disabled = false })" >/dev/null
}
mon_disable() {   # output
  hyprctl eval "hl.monitor({ output = \"$1\", disabled = true })" >/dev/null
}

# Brief OSD naming the layout we just switched to.
notify_mode() {   # mode-label
  notify-send -e -u low -t 1500 -h string:x-canonical-private-synchronous:monitor-auto \
    "󰍹 Display" "$1" 2>/dev/null || true
}

mode=""
if ext_connected; then
  if lid_closed; then
    # external only. Drop the internal panel FIRST so it never shares 0x0 with
    # the external (a transient overlap makes Hyprland latch a layout warning).
    mon_disable "$INT"
    mon_set "$EXT" "$EXT_MODE" "0x0"
    mode="External only"
  else
    # extend: internal on the left, external on the right. Park the external at
    # 1920x0 FIRST, then bring the internal in at 0x0 — never both at 0x0.
    mon_set "$EXT" "$EXT_MODE" "1920x0"
    mon_set "$INT" "$INT_MODE" "0x0"
    mode="Extended"
  fi
else
  if ! lid_closed; then
    # laptop only
    mon_set "$INT" "$INT_MODE" "0x0"
    mode="Laptop only"
  fi
  # no external + lid closed: leave displays as-is; logind handles suspend.
fi

[ -n "$mode" ] && notify_mode "$mode"
