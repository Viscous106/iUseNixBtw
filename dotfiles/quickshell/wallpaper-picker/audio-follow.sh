#!/usr/bin/env bash
# Keeps a sound-enabled video wallpaper audible only while its monitor's focused workspace is empty.
# Driven by Hyprland's socket2 (no polling); exits when mpv's IPC or Hyprland's socket closes.
set -uo pipefail

SOCK="${1:?usage: audio-follow.sh <mpv-ipc-socket> [MON]}"
MON="${2-}"
HYPRCTL="${HYPRCTL_BIN:-hyprctl}"
SOCAT="${SOCAT_BIN:-socat}"
EVENTS="${WP_HYPR_EVENTS:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE-}/.socket2.sock}"

# Empty focused workspace, on MON, and nothing focused. Any hyprctl failure
# reads as "not empty", so the failure mode is silence, never noise over an app.
desktop_empty() {
  local ws="" wsmon="" win
  read -r ws wsmon < <("$HYPRCTL" -j activeworkspace 2>/dev/null \
    | jq -r '"\(.windows // "") \(.monitor // "")"' 2>/dev/null)
  win="$("$HYPRCTL" -j activewindow 2>/dev/null | jq -r '.address // empty' 2>/dev/null)"
  [ "$ws" = 0 ] && [ -z "$win" ] && { [ -z "$MON" ] || [ "$wsmon" = "$MON" ]; }
}

# mpv JSON IPC. Non-zero when mpv is gone.
mpv_mute() { # mpv_mute true|false
  printf '{"command":["set_property","mute",%s]}\n' "$1" \
    | "$SOCAT" - "UNIX-CONNECT:$SOCK" >/dev/null 2>&1
}

last=""
update() {
  # mpv removes its socket on exit; don't wait for a mute change to notice.
  [ -S "$SOCK" ] || exit 0
  local want=true
  desktop_empty && want=false
  [ "$want" = "$last" ] && return 0
  mpv_mute "$want" || exit 0
  last="$want"
}

# mpvpaper is started in the background just before us; give its IPC socket
# a few seconds to appear. mpv starts muted, so waiting is silent.
for _ in $(seq 50); do
  [ -S "$SOCK" ] && break
  sleep 0.1
done
[ -S "$SOCK" ] || { echo "audio-follow: no mpv socket at $SOCK" >&2; exit 1; }

[ -S "$EVENTS" ] || {
  # Can't follow focus, so stay muted rather than play over whatever is open.
  echo "audio-follow: no Hyprland event socket at $EVENTS; leaving wallpaper muted" >&2
  exit 1
}

update

exec 3< <("$SOCAT" -U - "UNIX-CONNECT:$EVENTS" 2>/dev/null)
events_pid=$!
trap 'kill "$events_pid" 2>/dev/null' EXIT
trap 'exit 0' TERM INT

# Only events that can change "is the focused workspace empty"; the stream
# also carries a line per title change, which would be pure overhead.
while IFS= read -r line <&3; do
  case "$line" in
    workspace\>\>*|workspacev2\>\>*|focusedmon\>\>*|focusedmonv2\>\>*|\
    openwindow\>\>*|closewindow\>\>*|movewindow\>\>*|movewindowv2\>\>*|\
    activewindowv2\>\>*|activespecial\>\>*|activespecialv2\>\>*)
      update ;;
  esac
done
