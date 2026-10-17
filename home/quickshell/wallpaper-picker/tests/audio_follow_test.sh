#!/usr/bin/env bash
# Tests audio-follow.sh against fakes: a socat listener stands in for mpv's
# IPC socket (logging every command it receives), another for Hyprland's
# event socket (replaying an append-only file), and HYPRCTL_BIN reads the "desktop" from two
# files. Nothing touches the real session.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/../audio-follow.sh"
fails=0

command -v socat >/dev/null 2>&1 || { echo "SKIP: socat not available"; exit 0; }

work="$(mktemp -d)"
pids=()
trap 'kill "${pids[@]}" 2>/dev/null; rm -rf "$work"' EXIT

check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  ok: $1"; else
    echo "  FAIL: $1"; echo "    expected: $2"; echo "    actual:   $3"; fails=$((fails+1)); fi
}

# Desktop state the hyprctl stub reports.
echo 1 > "$work/ws_windows"
echo 0xabc > "$work/active"
export HYPRCTL_BIN="$work/hyprctl"
cat > "$HYPRCTL_BIN" <<STUB
#!/usr/bin/env bash
case "\$2" in
  activeworkspace) printf '{"id":1,"windows":%s}' "\$(cat "$work/ws_windows")" ;;
  activewindow)    a="\$(cat "$work/active")"
                   if [ -n "\$a" ]; then printf '{"address":"%s"}' "\$a"; else printf '{}'; fi ;;
esac
STUB
chmod +x "$HYPRCTL_BIN"

mpv="$work/mpv.sock"
: > "$work/mpv.log"
socat -u UNIX-LISTEN:"$mpv",fork OPEN:"$work/mpv.log",append >/dev/null 2>&1 &
pids+=($!)

export WP_HYPR_EVENTS="$work/events.sock"
: > "$work/events"
socat UNIX-LISTEN:"$WP_HYPR_EVENTS",fork EXEC:"tail -n +1 -F $work/events" >/dev/null 2>&1 &
pids+=($!)
for _ in $(seq 50); do [ -S "$mpv" ] && [ -S "$WP_HYPR_EVENTS" ] && break; sleep 0.05; done
exec 4>> "$work/events"

# Last mute value mpv was sent, after giving the follower time to react.
last_mute() {
  sleep 0.4
  grep -o '"mute",[a-z]*' "$work/mpv.log" | tail -1 | cut -d, -f2
}
sends() { grep -c '"mute"' "$work/mpv.log"; }

"$SUT" "$mpv" 2>"$work/err" &
follow=$!; pids+=($follow)

check "window on workspace: muted"  "true"  "$(last_mute)"

echo 0 > "$work/ws_windows"; : > "$work/active"
echo "workspace>>2" >&4
check "switch to empty workspace: unmuted" "false" "$(last_mute)"

n="$(sends)"
echo "windowtitle>>abc" >&4
echo "workspace>>3" >&4                 # still empty
sleep 0.4
check "irrelevant/unchanged events send nothing" "$n" "$(sends)"

echo 1 > "$work/ws_windows"; echo 0xdef > "$work/active"
echo "openwindow>>def,2,kitty,kitty" >&4
check "app opened: muted" "true" "$(last_mute)"

echo 0 > "$work/ws_windows"; : > "$work/active"
echo "closewindow>>def" >&4
check "last window closed: unmuted" "false" "$(last_mute)"

echo 0xfff > "$work/active"             # special workspace over an empty one
echo "activespecialv2>>-98,special:magic,HDMI-A-1" >&4
check "focused window on special workspace: muted" "true" "$(last_mute)"

# mpv gone (next apply killed mpvpaper): follower must exit by itself.
kill "${pids[0]}" 2>/dev/null; rm -f "$mpv"
: > "$work/active"
echo "workspace>>4" >&4
gone=0
for _ in $(seq 20); do kill -0 "$follow" 2>/dev/null || { gone=1; break; }; sleep 0.1; done
check "exits once mpv is gone" "1" "$gone"

# No Hyprland event socket: stays muted (never unmutes blind) and exits.
socat -u UNIX-LISTEN:"$mpv",fork OPEN:"$work/mpv.log",append >/dev/null 2>&1 &
pids+=($!)
for _ in $(seq 50); do [ -S "$mpv" ] && break; sleep 0.05; done
n="$(sends)"
WP_HYPR_EVENTS="$work/nope.sock" "$SUT" "$mpv" 2>/dev/null
check "no event socket exits non-zero" "1" "$?"
check "no event socket sends nothing" "$n" "$(sends)"

if [ "$fails" -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "FAILURES=$fails"; exit 1; fi
