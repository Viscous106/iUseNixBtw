#!/usr/bin/env bash
# Single apply path for the picker UI and `wallpaper-picker --restore`, so login matches what was picked.
# Per monitor (--output, else focused, else all); binaries come from env vars so tests can stub them.
set -uo pipefail

STATE_DIR="${WP_STATE_DIR:-$HOME/.local/state/wallpaper-picker}"
AWWW="${AWWW_BIN:-awww}"
MPVPAPER="${MPVPAPER_BIN:-mpvpaper}"
HYPRCTL="${HYPRCTL_BIN:-hyprctl}"
FOLLOW="${WP_FOLLOW_BIN:-$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/audio-follow.sh}"
SOCK_DIR="${WP_MPV_SOCK_DIR:-${XDG_RUNTIME_DIR:-/tmp}}"

TRANSITION_ARGS=(--transition-type random --transition-duration 0.6 --transition-fps 60)

die() { echo "wallpaper-picker: $*" >&2; exit 1; }

kind_of() {
  case "${1,,}" in
    *.mp4|*.mkv|*.webm)                  echo video ;;
    *.jpg|*.jpeg|*.png|*.webp|*.gif)     echo image ;;
    *)                                   echo unsupported ;;
  esac
}

# ── Monitors and per-monitor state ───────────────────────────────────────────
# State in $STATE_DIR/outputs/MON/; top-level files are the every-monitor fallback. MON "" = every monitor.

monitors()        { "$HYPRCTL" -j monitors 2>/dev/null | jq -r '.[].name' 2>/dev/null; }
focused_monitor() { "$HYPRCTL" -j monitors 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null | head -1; }

state_dir() { if [ -n "$1" ]; then echo "$STATE_DIR/outputs/$1"; else echo "$STATE_DIR"; fi; }

read_state() { # read_state <mon> current|kind|audio
  local d; d="$(state_dir "$1")"
  if [ -f "$d/$2" ]; then cat "$d/$2"; else cat "$STATE_DIR/$2" 2>/dev/null; fi
}

recorded_audio() { [ "$(read_state "$1" audio)" = on ] && echo on || echo off; }

record() { # record <mon> <path> <kind> <audio>
  local d; d="$(state_dir "$1")"
  mkdir -p "$d"
  printf '%s' "$2" > "$d/current"
  printf '%s' "$3" > "$d/kind"
  printf '%s' "$4" > "$d/audio"
  # An every-monitor apply replaces every monitor's own wallpaper too.
  [ -n "$1" ] || rm -rf "$STATE_DIR/outputs"
}

# ── Applying ─────────────────────────────────────────────────────────────────

# awww needs its daemon; starting it is cheap and idempotent, and lets it restore its own cached wallpaper.
ensure_awww_daemon() {
  command -v "$AWWW" >/dev/null 2>&1 || return 0
  if ! "$AWWW" query >/dev/null 2>&1; then
    "${AWWW}-daemon" >/dev/null 2>&1 &
    # Bounded poll, not a fixed sleep: at login the socket can take longer than 0.4s; give up after ~3s.
    for _ in $(seq 30); do
      "$AWWW" query >/dev/null 2>&1 && break
      sleep 0.1
    done
  fi
}

mpv_sock() { echo "$SOCK_DIR/wallpaper-picker-mpv-${1:-all}.sock"; }

# Stop MON's video + follower and any every-monitor one; matched by binary
# name/path so test stubs never touch the real ones.
stop_video() { # stop_video <mon>
  local mpv="${MPVPAPER##*/}"
  if [ -z "$1" ]; then
    pkill -f -- "$FOLLOW" >/dev/null 2>&1
    pkill -f -- "$mpv " >/dev/null 2>&1
  else
    pkill -f -- "$FOLLOW [^ ]*( $1)?\$" >/dev/null 2>&1
    pkill -f -- "$mpv .* (\\*|$1) /" >/dev/null 2>&1
  fi
}

apply_image() { # apply_image <path> <mon>
  command -v "$AWWW" >/dev/null 2>&1 || die "awww not found; cannot set an image wallpaper"
  ensure_awww_daemon
  stop_video "$2"
  local out=()
  [ -n "$2" ] && out=(-o "$2")
  "$AWWW" img "${out[@]}" "${TRANSITION_ARGS[@]}" "$1" || die "awww img failed"
}

apply_video() { # apply_video <path> on|off <mon>
  command -v "$MPVPAPER" >/dev/null 2>&1 || die "mpvpaper not found; cannot set a video wallpaper"
  # audio-follow.sh needs socat or the video stays muted forever; fail early so the picker shows why.
  if [ "$2" = on ] && ! command -v "${SOCAT_BIN:-socat}" >/dev/null 2>&1; then
    die "socat not found; cannot play a video wallpaper with sound"
  fi
  stop_video "$3"
  local mon="${3:-*}" sock
  if [ "$2" = on ]; then
    # Starts muted; audio-follow.sh unmutes it once it has checked focus, so
    # there is never a burst of sound over an open app.
    sock="$(mpv_sock "$3")"
    rm -f "$sock"
    "$MPVPAPER" -o "loop mute=yes input-ipc-server=$sock" "$mon" "$1" >/dev/null 2>&1 &
    if [ -n "$3" ]; then
      "$FOLLOW" "$sock" "$3" >/dev/null 2>&1 </dev/null &
    else
      "$FOLLOW" "$sock" >/dev/null 2>&1 </dev/null &
    fi
  else
    "$MPVPAPER" -o "no-audio --loop" "$mon" "$1" >/dev/null 2>&1 &
  fi
}

apply_path() { # apply_path <path> on|off <mon>
  local path="$1" audio="$2" mon="$3" kind
  [ -f "$path" ] || die "no such file: $path"
  kind="$(kind_of "$path")"
  [ "$kind" = unsupported ] && die "unsupported file type: $path"
  [ "$kind" = video ] || audio=off
  if [ "$kind" = video ]; then apply_video "$path" "$audio" "$mon"; else apply_image "$path" "$mon"; fi
  record "$mon" "$path" "$kind" "$audio"
}

# Never fails: a login hook must not fail loudly, and one monitor's broken
# wallpaper must not cost the others theirs.
restore_one() { # restore_one <mon>
  local path
  path="$(read_state "$1" current)"
  if [ -n "$path" ] && [ -f "$path" ]; then
    # Subshell: apply_path can die()/exit, which would skip the fallback and exit 0 and leave a blank desktop.
    if ! ( apply_path "$path" "$(recorded_audio "$1")" "$1" ); then
      # Nothing behind it: start the daemon so awww's cached image paints instead of a blank desktop.
      ensure_awww_daemon >/dev/null 2>&1
    fi
  else
    # Nothing usable recorded: not an error, but start awww-daemon so it restores its cached wallpaper.
    ensure_awww_daemon >/dev/null 2>&1
  fi
}

# ── Arguments ────────────────────────────────────────────────────────────────

usage="usage: apply.sh [--output MON] <path> [--sound] | [--output MON] --current | [--output MON] --current-audio | --restore"
cmd=apply path="" sound=off output="" output_set=0
while [ $# -gt 0 ]; do
  case "$1" in
    --output)        [ $# -ge 2 ] && [ -n "$2" ] || die "$usage"
                     output="$2"; output_set=1; shift 2 ;;
    --sound)         sound=on; shift ;;
    --restore)       cmd=restore; shift ;;
    --current)       cmd=current; shift ;;
    # Separate from --current so that keeps printing exactly the path.
    --current-audio) cmd=current-audio; shift ;;
    "" | -*)         die "$usage" ;;
    *)               [ -z "$path" ] || die "$usage"
                     path="$1"; shift ;;
  esac
done
[ "$output_set" = 1 ] || output="$(focused_monitor)"

case "$cmd" in
  restore)
    mons="$(monitors)"
    if [ -n "$mons" ]; then
      while IFS= read -r m; do restore_one "$m"; done <<< "$mons"
    else
      restore_one ""
    fi
    exit 0
    ;;
  current)       read_state "$output" current || true ;;
  current-audio) recorded_audio "$output" ;;
  apply)
    [ -n "$path" ] || die "$usage"
    apply_path "$path" "$sound" "$output"
    ;;
esac
