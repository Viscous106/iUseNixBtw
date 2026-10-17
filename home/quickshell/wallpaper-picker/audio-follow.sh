#!/usr/bin/env bash
# Keeps a sound-enabled video wallpaper quiet while you're using an app.
#
#   audio-follow.sh <mpv-ipc-socket>
#
# Started by apply.sh only when a video was applied WITH sound. Rule: the
# wallpaper is audible only while the focused workspace is empty (nothing to
# look at but the desktop); any window on it -- or a focused window anywhere,
# e.g. a special workspace overlaid on an empty one -- mutes it.
#
# Driven by Hyprland's socket2 event stream rather than polling, so it costs
# nothing while idle. Exits when mpv's IPC socket stops answering (mpvpaper
# killed by the next apply), or when Hyprland's socket closes.
#
# Binaries are indirected through env vars so tests can stub them.
set -uo pipefail

SOCK="${1:?usage: audio-follow.sh <mpv-ipc-socket>}"
HYPRCTL="${HYPRCTL_BIN:-hyprctl}"
SOCAT="${SOCAT_BIN:-socat}"
EVENTS="${WP_HYPR_EVENTS:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE-}/.socket2.sock}"

# Empty focused workspace and nothing focused. Any hyprctl failure reads as
# "not empty", so the failure mode is silence, never noise over an app.
desktop_empty() {
  local ws win
  ws="$("$HYPRCTL" -j activeworkspace 2>/dev/null | jq -r '.windows // empty' 2>/dev/null)"
  win="$("$HYPRCTL" -j activewindow 2>/dev/null | jq -r '.address // empty' 2>/dev/null)"
  [ "$ws" = 0 ] && [ -z "$win" ]
}

# mpv JSON IPC. Non-zero when mpv is gone.
mpv_mute() { # mpv_mute true|false
  printf '{"command":["set_property","mute",%s]}\n' "$1" \
    | "$SOCAT" - "UNIX-CONNECT:$SOCK" >/dev/null 2>&1
}

last=""
update() {
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
