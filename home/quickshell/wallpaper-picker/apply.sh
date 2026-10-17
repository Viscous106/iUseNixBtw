#!/usr/bin/env bash
# Single apply path for the wallpaper picker.
#
# Both the QML UI (via Applier.qml) and `wallpaper-picker --restore` call this,
# so what happens at login is byte-for-byte what happened when you picked it.
#
#   apply.sh [--output MON] <path> [--sound]
#   apply.sh [--output MON] --current | --current-audio
#   apply.sh --restore
#
# Wallpapers are per monitor. --output names the monitor; without it, the one
# Hyprland has focused. If no monitor can be determined at all (no hyprctl),
# the wallpaper goes on every monitor, as it did before wallpapers were per
# monitor.
#
# --sound only matters for videos: without it mpv runs with no audio at all;
# with it, audio-follow.sh keeps it muted unless its monitor is focused and
# showing an empty workspace.
#
# Binaries are indirected through env vars so tests can stub them.
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
#
# State for monitor MON lives in $STATE_DIR/outputs/MON/{current,kind,audio}.
# The files directly in $STATE_DIR are the pre-per-monitor ("every monitor")
# state: a monitor with nothing of its own falls back to them, so existing
# setups keep their wallpaper, and they are what an unknown-monitor apply
# writes. Every function below takes MON, where "" means "every monitor".

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

mpv_sock() { echo "$SOCK_DIR/wallpaper-picker-mpv-${1:-all}.sock"; }

# The video wallpaper (and its focus-follower) on MON, plus any every-monitor
# one, since that one covers MON too. Matched on the binaries' own names and
# paths, so a test's stubs never touch the real ones.
#   mpvpaper cmdline: mpvpaper -o <opts> <MON|*> <path>
#   follower cmdline: bash audio-follow.sh <sock> [MON]
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
  # audio-follow.sh talks to mpv and Hyprland over socat. Without it the
  # follower dies on its first unmute and the video stays muted forever --
  # fail before touching anything, so the picker shows why there is no sound.
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
    # Run in a subshell: apply_path can die() on failure (e.g. `awww img`
    # erroring out), and die() calls `exit`, which would otherwise tear
    # down this whole script before reaching the fallback and the `exit 0`
    # in --restore -- exactly the blank-desktop, fail-loudly login regression
    # this exists to avoid.
    if ! ( apply_path "$path" "$(recorded_audio "$1")" "$1" ); then
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
