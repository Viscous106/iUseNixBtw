#!/run/current-system/sw/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
#
# Made and brought to by Kiran George
# /* -- ✨ https://github.com/SherLock707 ✨ -- */  ##
# Dropdown Terminal
# Usage: ./Dropterminal.sh [-d] <terminal_command>
# Example: ./Dropterminal.sh foot
#          ./Dropterminal.sh -d foot (with debug output)
#          ./Dropterminal.sh "kitty -e zsh"
#
# NOTE: this script targets Hyprland's *Lua* config API (0.55+). Dispatchers are
# issued as Lua, e.g.  hyprctl dispatch 'hl.dsp.window.pin({ window = "address:0x.." })'
# The old hyprlang strings ("pin address:0x..") are no longer parsed and silently fail.

DEBUG=false
SPECIAL_WS="special:scratchpad"
TAG="dropterm" # window tag used to identify our terminal

# Dropdown size and position configuration (percentages)
WIDTH_PERCENT=50  # Width as percentage of screen width
HEIGHT_PERCENT=50 # Height as percentage of screen height
Y_PERCENT=10      # Y position as percentage from top (X is auto-centered)

# Animation settings
SLIDE_STEPS=5

# How long to wait for a freshly spawned terminal to map (0.1s per tick)
SPAWN_TIMEOUT=50

# Parse arguments
PREWARM=false
while true; do
  case "$1" in
  -d) DEBUG=true; shift ;;
  # Spawn the terminal into the scratchpad and leave it hidden. Used at startup
  # so the first toggle is instant, without the terminal popping open at login.
  --prewarm) PREWARM=true; shift ;;
  *) break ;;
  esac
done

TERMINAL_CMD="$1"

# Debug echo -> stderr. Must NOT go to stdout: several helpers below are called
# inside $( ), and debug lines on stdout would corrupt their return values.
debug_echo() {
  if [ "$DEBUG" = true ]; then
    echo "$@" >&2
  fi
}

# Validate input
if [ -z "$TERMINAL_CMD" ]; then
  echo "Missing terminal command. Usage: $0 [-d] <terminal_command>"
  echo "Examples:"
  echo "  $0 foot"
  echo "  $0 -d foot (with debug output)"
  echo "  $0 'kitty -e zsh'"
  echo ""
  echo "Edit the script to modify size and position:"
  echo "  WIDTH_PERCENT  - Width as percentage of screen (default: 50)"
  echo "  HEIGHT_PERCENT - Height as percentage of screen (default: 50)"
  echo "  Y_PERCENT      - Y position from top as percentage (default: 10)"
  echo "  Note: X position is automatically centered"
  exit 1
fi

# ----------------------------------------------------------------- lua helpers

# Issue a Lua dispatcher and surface errors when debugging.
dispatch() {
  local out
  out=$(hyprctl dispatch "$1" 2>&1)
  if [[ "$out" == error* ]]; then
    debug_echo "dispatch failed: $1"
    debug_echo "  -> $out"
    return 1
  fi
  return 0
}

win_move_exact() { # addr x y
  dispatch "hl.dsp.window.move({ x = $2, y = $3, relative = false, window = \"address:$1\" })"
}

win_resize_exact() { # addr w h
  dispatch "hl.dsp.window.resize({ x = $2, y = $3, relative = false, window = \"address:$1\" })"
}

win_to_workspace_silent() { # addr workspace
  dispatch "hl.dsp.window.move({ workspace = \"$2\", follow = false, window = \"address:$1\" })"
}

win_pin() { # addr on|off
  dispatch "hl.dsp.window.pin({ action = \"$2\", window = \"address:$1\" })"
}

win_focus() { # addr
  dispatch "hl.dsp.focus({ window = \"address:$1\" })"
}

# ------------------------------------------------------------ window discovery

# The dropdown terminal is identified by its tag, not by a cached address.
# A cached address is unreliable: addresses are reused, and if the lookup ever
# resolves to the wrong window the script happily starts toggling *that* window
# (e.g. your browser) in and out of the scratchpad.
# Note: tags applied by a window rule are reported with a trailing "*"
# (e.g. "dropterm*"), so match both forms.
get_terminal_address() {
  hyprctl clients -j | jq -r --arg T "$TAG" \
    '[.[] | select(any(.tags[]; . == $T or . == $T + "*"))] | .[0].address // empty'
}

terminal_exists() {
  [ -n "$(get_terminal_address)" ]
}

terminal_in_special() { # addr
  hyprctl clients -j | jq -e --arg ADDR "$1" --arg WS "$SPECIAL_WS" \
    'any(.[]; .address == $ADDR and .workspace.name == $WS)' >/dev/null 2>&1
}

get_window_geometry() { # addr
  hyprctl clients -j | jq -r --arg ADDR "$1" \
    '.[] | select(.address == $ADDR) | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"'
}

# --------------------------------------------------------------- monitor / geom

get_monitor_info() {
  local monitor_data
  monitor_data=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.x) \(.y) \(.width) \(.height) \(.scale) \(.name)"')
  if [ -z "$monitor_data" ] || [[ "$monitor_data" =~ ^null ]]; then
    debug_echo "Error: Could not get focused monitor information"
    return 1
  fi
  echo "$monitor_data"
}

calculate_dropdown_position() {
  local monitor_info
  monitor_info=$(get_monitor_info) || {
    debug_echo "Error: Failed to get monitor info, using fallback values"
    echo "100 100 800 600 fallback-monitor"
    return 1
  }

  local mon_x mon_y mon_width mon_height mon_scale mon_name
  read -r mon_x mon_y mon_width mon_height mon_scale mon_name <<<"$monitor_info"

  debug_echo "Monitor: x=$mon_x y=$mon_y ${mon_width}x${mon_height} scale=$mon_scale ($mon_name)"

  if [ -z "$mon_scale" ] || [ "$mon_scale" = "null" ] || [ "$mon_scale" = "0" ]; then
    debug_echo "Invalid scale value, using 1.0 as fallback"
    mon_scale="1.0"
  fi

  # Hyprland dispatchers take *logical* coordinates: physical / scale.
  local logical_width logical_height
  if command -v bc >/dev/null 2>&1; then
    logical_width=$(echo "scale=0; $mon_width / $mon_scale" | bc | cut -d'.' -f1)
    logical_height=$(echo "scale=0; $mon_height / $mon_scale" | bc | cut -d'.' -f1)
  else
    local scale_int
    scale_int=$(echo "$mon_scale" | sed 's/\.//' | sed 's/^0*//')
    [ -z "$scale_int" ] && scale_int=100
    logical_width=$(((mon_width * 100) / scale_int))
    logical_height=$(((mon_height * 100) / scale_int))
  fi

  [[ "$logical_width" =~ ^-?[0-9]+$ ]] || logical_width=$mon_width
  [[ "$logical_height" =~ ^-?[0-9]+$ ]] || logical_height=$mon_height

  local width=$((logical_width * WIDTH_PERCENT / 100))
  local height=$((logical_height * HEIGHT_PERCENT / 100))
  local y_offset=$((logical_height * Y_PERCENT / 100))
  local x_offset=$(((logical_width - width) / 2))

  local final_x=$((mon_x + x_offset))
  local final_y=$((mon_y + y_offset))

  debug_echo "Dropdown: ${width}x${height} at ${final_x},${final_y} (logical)"

  echo "$final_x $final_y $width $height $mon_name"
}

# ------------------------------------------------------------------- animation

animate_slide_down() { # addr target_x target_y width height
  local addr="$1" target_x="$2" target_y="$3" height="$5"
  local start_y=$((target_y - height - 50))
  local step_y=$(((target_y - start_y) / SLIDE_STEPS))

  debug_echo "Slide down -> $target_x,$target_y"

  win_move_exact "$addr" "$target_x" "$start_y"
  sleep 0.05

  for i in $(seq 1 $SLIDE_STEPS); do
    win_move_exact "$addr" "$target_x" "$((start_y + step_y * i))"
    sleep 0.03
  done

  win_move_exact "$addr" "$target_x" "$target_y"
}

animate_slide_up() { # addr start_x start_y width height
  local addr="$1" start_x="$2" start_y="$3" height="$5"
  local end_y=$((start_y - height - 50))
  local step_y=$(((start_y - end_y) / SLIDE_STEPS))

  debug_echo "Slide up from $start_x,$start_y"

  for i in $(seq 1 $SLIDE_STEPS); do
    win_move_exact "$addr" "$start_x" "$((start_y - step_y * i))"
    sleep 0.03
  done
}

# ----------------------------------------------------------------------- spawn

spawn_terminal() {
  debug_echo "Creating new dropdown terminal: $TERMINAL_CMD"

  local pos_info target_x target_y width height
  pos_info=$(calculate_dropdown_position)
  read -r target_x target_y width height _ <<<"$pos_info"

  # Spawn straight into the scratchpad so it never flashes on screen, and tag it
  # so we can find it again without caching an address.
  dispatch "hl.dsp.exec_cmd([[$TERMINAL_CMD]], {
      float = true,
      size = \"$width $height\",
      workspace = \"$SPECIAL_WS silent\",
      tag = \"+$TAG\",
    })" || {
    debug_echo "exec_cmd dispatch failed"
    return 1
  }

  # Poll until it maps. A fixed short sleep is not enough - terminals routinely
  # take several hundred ms to appear, and the old code fell back to "grab some
  # arbitrary window" when it lost that race.
  local addr="" i=0
  while [ $i -lt $SPAWN_TIMEOUT ]; do
    addr=$(get_terminal_address)
    [ -n "$addr" ] && break
    sleep 0.1
    i=$((i + 1))
  done

  if [ -z "$addr" ]; then
    debug_echo "Timed out waiting for the terminal window to appear"
    return 1
  fi

  debug_echo "Terminal mapped at $addr"

  if [ "$PREWARM" = true ]; then
    debug_echo "Pre-warm mode: leaving terminal hidden in $SPECIAL_WS"
    return 0
  fi

  local current_ws
  current_ws=$(hyprctl activeworkspace -j | jq -r '.id')

  win_to_workspace_silent "$addr" "$current_ws"
  win_pin "$addr" on
  animate_slide_down "$addr" "$target_x" "$target_y" "$width" "$height"
  win_focus "$addr"
  return 0
}

# ------------------------------------------------------------------ main logic

CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')
TERMINAL_ADDR=$(get_terminal_address)

if [ -z "$TERMINAL_ADDR" ]; then
  debug_echo "No existing terminal found, creating new one"
  spawn_terminal
  exit $?
fi

debug_echo "Found existing terminal: $TERMINAL_ADDR"

if [ "$PREWARM" = true ]; then
  debug_echo "Pre-warm mode: terminal already exists, nothing to do"
  exit 0
fi

pos_info=$(calculate_dropdown_position)
read -r target_x target_y width height _ <<<"$pos_info"

if terminal_in_special "$TERMINAL_ADDR"; then
  debug_echo "Showing terminal"

  win_to_workspace_silent "$TERMINAL_ADDR" "$CURRENT_WS"
  win_pin "$TERMINAL_ADDR" on
  win_resize_exact "$TERMINAL_ADDR" "$width" "$height"
  animate_slide_down "$TERMINAL_ADDR" "$target_x" "$target_y" "$width" "$height"
  win_focus "$TERMINAL_ADDR"
else
  debug_echo "Hiding terminal"

  geometry=$(get_window_geometry "$TERMINAL_ADDR")
  if [ -n "$geometry" ]; then
    read -r curr_x curr_y curr_width curr_height <<<"$geometry"
    debug_echo "Current geometry: ${curr_x},${curr_y} ${curr_width}x${curr_height}"
    animate_slide_up "$TERMINAL_ADDR" "$curr_x" "$curr_y" "$curr_width" "$curr_height"
    sleep 0.1
  else
    debug_echo "Could not get window geometry, hiding without animation"
  fi

  win_pin "$TERMINAL_ADDR" off
  win_to_workspace_silent "$TERMINAL_ADDR" "$SPECIAL_WS"
fi
