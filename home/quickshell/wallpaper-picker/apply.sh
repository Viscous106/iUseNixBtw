#!/usr/bin/env bash
# Single apply path for the wallpaper picker.
#
# Both the QML UI (via Applier.qml) and `wallpaper-picker --restore` call this,
# so what happens at login is byte-for-byte what happened when you picked it.
#
#   apply.sh <path> [--sound]   --sound only matters for videos: without it
#                               mpv runs with no audio at all; with it,
#                               audio-follow.sh mutes it whenever the focused
#                               workspace has a window on it.
#
# Binaries are indirected through env vars so tests can stub them.
set -uo pipefail

STATE_DIR="${WP_STATE_DIR:-$HOME/.local/state/wallpaper-picker}"
AWWW="${AWWW_BIN:-awww}"
MPVPAPER="${MPVPAPER_BIN:-mpvpaper}"
FOLLOW="${WP_FOLLOW_BIN:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/audio-follow.sh}"
MPV_SOCK="${WP_MPV_SOCK:-${XDG_RUNTIME_DIR:-/tmp}/wallpaper-picker-mpv.sock}"

TRANSITION_ARGS=(--transition-type random --transition-duration 0.6 --transition-fps 60)

die() { echo "wallpaper-picker: $*" >&2; exit 1; }

kind_of() {
  case "${1,,}" in
    *.mp4|*.mkv|*.webm)                  echo video ;;
    *.jpg|*.jpeg|*.png|*.webp|*.gif)     echo image ;;
    *)                                   echo unsupported ;;
  esac
}

# awww needs its daemon; starting it when absent is cheap and idempotent.
# Also used by --restore when there's no recorded state, so awww-daemon can
# restore its own cached wallpaper (mirrors the old wallpaper-restore.sh).
ensure_awww_daemon() {
  command -v "$AWWW" >/dev/null 2>&1 || return 0
  if ! "$AWWW" query >/dev/null 2>&1; then
    "${AWWW}-daemon" >/dev/null 2>&1 &
    # Bounded poll instead of a fixed sleep: at login this runs on a cold,
    # contended system where 0.4s is not always enough for the socket to come
    # up, and a fixed sleep either wastes time or isn't enough. Proceed the
    # moment the daemon answers; give up after ~3s.
    for _ in $(seq 30); do
      "$AWWW" query >/dev/null 2>&1 && break
      sleep 0.1
    done
  fi
}

# Any running video wallpaper and its focus-follower. The follower is matched
# on its own path, so a test's stub never touches the real one.
stop_video() {
  pkill -f -- "$FOLLOW" >/dev/null 2>&1
  pkill -f mpvpaper >/dev/null 2>&1
}

apply_image() {
  command -v "$AWWW" >/dev/null 2>&1 || die "awww not found; cannot set an image wallpaper"
  ensure_awww_daemon
  stop_video
  "$AWWW" img "${TRANSITION_ARGS[@]}" "$1" || die "awww img failed"
}

apply_video() { # apply_video <path> on|off
  command -v "$MPVPAPER" >/dev/null 2>&1 || die "mpvpaper not found; cannot set a video wallpaper"
  # audio-follow.sh talks to mpv and Hyprland over socat. Without it the
  # follower dies on its first unmute and the video stays muted forever --
  # fail before touching anything, so the picker shows why there is no sound.
  if [ "$2" = on ] && ! command -v "${SOCAT_BIN:-socat}" >/dev/null 2>&1; then
    die "socat not found; cannot play a video wallpaper with sound"
  fi
  stop_video
  local mon
  mon="$(hyprctl -j monitors 2>/dev/null | jq -r '.[0].name' 2>/dev/null)"
  [ -n "$mon" ] && [ "$mon" != "null" ] || mon="*"
  if [ "$2" = on ]; then
    # Starts muted; audio-follow.sh unmutes it once it has checked focus, so
    # there is never a burst of sound over an open app.
    rm -f "$MPV_SOCK"
    "$MPVPAPER" -o "loop mute=yes input-ipc-server=$MPV_SOCK" "$mon" "$1" >/dev/null 2>&1 &
    "$FOLLOW" "$MPV_SOCK" >/dev/null 2>&1 </dev/null &
  else
    "$MPVPAPER" -o "no-audio --loop" "$mon" "$1" >/dev/null 2>&1 &
  fi
}

record() {
  mkdir -p "$STATE_DIR"
  printf '%s' "$1" > "$STATE_DIR/current"
  printf '%s' "$2" > "$STATE_DIR/kind"
  printf '%s' "$3" > "$STATE_DIR/audio"
}

apply_path() { # apply_path <path> on|off
  local path="$1" audio="$2" kind
  [ -f "$path" ] || die "no such file: $path"
  kind="$(kind_of "$path")"
  [ "$kind" = unsupported ] && die "unsupported file type: $path"
  [ "$kind" = video ] || audio=off
  if [ "$kind" = video ]; then apply_video "$path" "$audio"; else apply_image "$path"; fi
  record "$path" "$kind" "$audio"
}

recorded_audio() {
  [ "$(cat "$STATE_DIR/audio" 2>/dev/null)" = on ] && echo on || echo off
}

case "${1-}" in
  --restore)
    path="$(cat "$STATE_DIR/current" 2>/dev/null)"
    if [ -n "$path" ] && [ -f "$path" ]; then
      # Run in a subshell: apply_path can die() on failure (e.g. `awww img`
      # erroring out), and die() calls `exit`, which would otherwise tear
      # down this whole script before reaching the fallback and the `exit 0`
      # below -- exactly the blank-desktop, fail-loudly login regression
      # this branch exists to avoid.
      if ! ( apply_path "$path" "$(recorded_audio)" ); then
        # apply_path failed with nothing behind it. Fall back to getting the
        # daemon up so awww's own cached image paints something instead of
        # leaving the desktop blank.
        ensure_awww_daemon >/dev/null 2>&1
      fi
    else
      # nothing usable recorded (missing state, or the file it named is gone):
      # not an error, but still get awww-daemon up so it can restore its own
      # cached wallpaper instead of leaving a blank desktop.
      ensure_awww_daemon >/dev/null 2>&1
    fi
    exit 0
    ;;
  --current)
    cat "$STATE_DIR/current" 2>/dev/null || true
    ;;
  --current-audio)
    # Separate from --current so that keeps printing exactly the path.
    recorded_audio
    ;;
  "" | -*)
    die "usage: apply.sh <path> [--sound] | --restore | --current | --current-audio"
    ;;
  *)
    case "${2-}" in
      "")      apply_path "$1" off ;;
      --sound) apply_path "$1" on ;;
      *)       die "usage: apply.sh <path> [--sound]" ;;
    esac
    ;;
esac
