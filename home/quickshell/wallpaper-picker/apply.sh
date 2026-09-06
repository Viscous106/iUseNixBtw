#!/usr/bin/env bash
# Single apply path for the wallpaper picker.
#
# Both the QML UI (via Applier.qml) and `wallpaper-picker --restore` call this,
# so what happens at login is byte-for-byte what happened when you picked it.
#
# Binaries are indirected through env vars so tests can stub them.
set -uo pipefail

STATE_DIR="${WP_STATE_DIR:-$HOME/.local/state/wallpaper-picker}"
AWWW="${AWWW_BIN:-awww}"
MPVPAPER="${MPVPAPER_BIN:-mpvpaper}"

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

apply_image() {
  command -v "$AWWW" >/dev/null 2>&1 || die "awww not found; cannot set an image wallpaper"
  ensure_awww_daemon
  pkill -f mpvpaper >/dev/null 2>&1
  "$AWWW" img "${TRANSITION_ARGS[@]}" "$1" || die "awww img failed"
}

apply_video() {
  command -v "$MPVPAPER" >/dev/null 2>&1 || die "mpvpaper not found; cannot set a video wallpaper"
  pkill -f mpvpaper >/dev/null 2>&1
  local mon
  mon="$(hyprctl -j monitors 2>/dev/null | jq -r '.[0].name' 2>/dev/null)"
  [ -n "$mon" ] && [ "$mon" != "null" ] || mon="*"
  "$MPVPAPER" -o "no-audio --loop" "$mon" "$1" >/dev/null 2>&1 &
}

record() {
  mkdir -p "$STATE_DIR"
  printf '%s' "$1" > "$STATE_DIR/current"
  printf '%s' "$2" > "$STATE_DIR/kind"
}

apply_path() {
  local path="$1" kind
  [ -f "$path" ] || die "no such file: $path"
  kind="$(kind_of "$path")"
  [ "$kind" = unsupported ] && die "unsupported file type: $path"
  if [ "$kind" = video ]; then apply_video "$path"; else apply_image "$path"; fi
  record "$path" "$kind"
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
      if ! ( apply_path "$path" ); then
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
  "" | -*)
    die "usage: apply.sh <path> | --restore | --current"
    ;;
  *)
    apply_path "$1"
    ;;
esac
