#!/usr/bin/env bash
# Accelerometer-driven screen rotation for this convertible Chromebook
# (Google "Ampton", Octopus / Gemini Lake).
#
# Rotation is deliberately gated on TABLET MODE — the accelerometer is only
# obeyed once the lid is folded past ~180° and the EC reports SW_TABLET_MODE.
# In normal laptop mode the panel never rotates no matter how far you lean the
# screen back. This is what ChromeOS does on this exact machine.
#
# Folding also mutes the built-in keyboard and touchpad, so palms on the back of
# the panel don't type. Unfolding restores everything.
#
# Subcommands:
#   init            session start: force the safe state, then correct it if we
#                   booted already folded
#   tablet on|off   called from the Hyprland switch binds in lua/laptops.lua
#   daemon          follow iio-sensor-proxy and apply rotation while folded
#
# Portable-safe: `daemon` exits immediately on a machine with no accelerometer,
# and `init` leaves a non-convertible in exactly the state it was already in.

set -u

INT="eDP-1"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}"
TRANSFORM_FILE="$STATE_DIR/hypr-rotation"          # also read by monitor-auto.sh
SENSOR_FILE="$STATE_DIR/hypr-rotation-sensor"      # last orientation the sensor reported
TABLET_FILE="$STATE_DIR/hypr-tablet-mode"          # exists == folded

# Devices muted while folded.
#
# keyd GRABS the physical keyboard and re-emits through keyd-virtual-keyboard —
# Hyprland reports that virtual device as "main: yes". So disabling
# at-translated-set-2-keyboard alone would do nothing at all; the virtual
# devices have to go too. kanata sits in the same chain and brings its own
# pointer (kanata-1).
#
# ydotoold-virtual-device is deliberately NOT muted: it is scripted/synthetic
# input (wl-kbptr and friends), not something a palm can press.
TABLET_MUTE=(
  at-translated-set-2-keyboard
  keyd-virtual-keyboard
  kanata
  elan-touchpad
  keyd-virtual-pointer
  kanata-1
)

# Same call convention as monitor-auto.sh: this build uses the non-legacy (Lua)
# parser, so `hyprctl keyword` is rejected outright ("keyword can't work with
# non-legacy parsers. Use eval.") and everything goes through hyprctl eval.
hy() { hyprctl eval "$1" >/dev/null 2>&1; }

# A bare output+transform rule is enough — Hyprland keeps the panel's existing
# mode, position and scale, so this does not have to know or restate the layout
# that monitor-auto.sh decided.
apply_transform() {
  local t="$1"
  echo "$t" > "$TRANSFORM_FILE"
  hy "hl.monitor({ output = \"$INT\", transform = $t })"
}

set_devices() {   # true|false
  local en="$1" d
  for d in "${TABLET_MUTE[@]}"; do
    hy "hl.device({ name = \"$d\", enabled = $en })"
  done
}

orientation_to_transform() {
  case "$1" in
    normal)    echo 0 ;;
    left-up)   echo 1 ;;
    bottom-up) echo 2 ;;
    right-up)  echo 3 ;;
    *)         echo "" ;;
  esac
}

last_sensor_transform() {
  local t
  t=$(cat "$SENSOR_FILE" 2>/dev/null)
  case "$t" in 0|1|2|3) echo "$t" ;; *) echo 0 ;; esac
}

tablet_active() { [ -e "$TABLET_FILE" ]; }

# The EC exposes folding as an evdev switch; find it by name rather than
# hardcoding an event number, which moves between boots.
tablet_switch_node() {
  local d n
  for d in /sys/class/input/event*; do
    n=$(cat "$d/device/name" 2>/dev/null) || continue
    if [ "$n" = "Tablet Mode Switch" ]; then
      echo "/dev/input/$(basename "$d")"
      return 0
    fi
  done
  return 1
}

# evtest --query exits 10 when the queried bit is SET, 0 when clear.
tablet_is_folded() {
  local node
  command -v evtest >/dev/null 2>&1 || return 1
  node=$(tablet_switch_node) || return 1
  evtest --query "$node" EV_SW SW_TABLET_MODE >/dev/null 2>&1
  [ "$?" -eq 10 ]
}

case "${1:-}" in
  init)
    # Fail safe: whatever a previous session left behind, come up unrotated with
    # every input device live. If the script ever dies mid-fold, the next login
    # hands the keyboard back.
    rm -f "$TABLET_FILE"
    set_devices true
    apply_transform 0
    # ...then correct it if we actually booted folded.
    if tablet_is_folded; then
      exec "$0" tablet on
    fi
    ;;

  tablet)
    case "${2:-}" in
      on)
        touch "$TABLET_FILE"
        set_devices false
        apply_transform "$(last_sensor_transform)"
        ;;
      off)
        rm -f "$TABLET_FILE"
        apply_transform 0
        set_devices true
        ;;
      *)
        echo "usage: $0 tablet on|off" >&2
        exit 2
        ;;
    esac
    ;;

  daemon)
    # No accelerometer (or no iio-sensor-proxy) -> nothing to follow.
    command -v monitor-sensor >/dev/null 2>&1 || exit 0
    ls -d /sys/bus/iio/devices/iio:device* >/dev/null 2>&1 || exit 0

    # One daemon per session.
    exec 8>"$STATE_DIR/hypr-auto-rotate.lock"
    flock -n 8 || exit 0

    while :; do
      # stdbuf: monitor-sensor's stdout is block-buffered down a pipe, so
      # without this the orientation lines arrive in 4K clumps, minutes late.
      stdbuf -oL monitor-sensor 2>/dev/null | while IFS= read -r line; do
        case "$line" in
          *"orientation changed: "*) o=${line##*"orientation changed: "} ;;
          *"(orientation: "*)        o=${line##*"(orientation: "}; o=${o%%)*} ;;
          *)                         continue ;;
        esac
        o=${o//[[:space:]]/}

        t=$(orientation_to_transform "$o")
        [ -n "$t" ] || continue

        # Always record what the sensor says, even in laptop mode — that is what
        # makes the panel snap to the right orientation the instant you fold.
        echo "$t" > "$SENSOR_FILE"

        tablet_active || continue
        apply_transform "$t"
      done
      # iio-sensor-proxy restarted or went away; wait and re-attach.
      sleep 5
    done
    ;;

  *)
    echo "usage: $0 {init|tablet on|tablet off|daemon}" >&2
    exit 2
    ;;
esac
