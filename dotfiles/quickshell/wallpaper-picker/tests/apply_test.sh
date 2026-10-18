#!/usr/bin/env bash
# Tests apply.sh without touching the real desktop: AWWW_BIN/MPVPAPER_BIN are
# overridden with stubs that just log their arguments.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="$HERE/../apply.sh"
fails=0

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export WP_STATE_DIR="$work/state"
export AWWW_BIN="$work/awww-stub"
export MPVPAPER_BIN="$work/mpvpaper-stub"
# Overridden too, so stop_video's `pkill -f $FOLLOW` can never hit the real one.
export WP_FOLLOW_BIN="$work/follow-stub"
export WP_MPV_SOCK_DIR="$work"
# hyprctl reports whatever monitors.json says; with no such file it fails, which
# is the "monitor unknown → every monitor" fallback the first half tests.
export HYPRCTL_BIN="$work/hyprctl-stub"
printf '#!/usr/bin/env bash\n[ "$2" = monitors ] && cat "%s/monitors.json" 2>/dev/null\n' "$work" > "$HYPRCTL_BIN"
chmod +x "$HYPRCTL_BIN"
# apply.sh only checks socat exists (the follower is stubbed), so any binary does.
export SOCAT_BIN=true
printf '#!/usr/bin/env bash\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
printf '#!/usr/bin/env bash\necho "mpvpaper $*" >> "%s/calls"\n' "$work" > "$MPVPAPER_BIN"
printf '#!/usr/bin/env bash\necho "follow $*" >> "%s/calls"\n' "$work" > "$WP_FOLLOW_BIN"
chmod +x "$AWWW_BIN" "$MPVPAPER_BIN" "$WP_FOLLOW_BIN"

img="$work/pic.png"; : > "$img"
vid="$work/clip.mp4"; : > "$vid"

check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  ok: $1"; else
    echo "  FAIL: $1"; echo "    expected: $2"; echo "    actual:   $3"; fails=$((fails+1)); fi
}

"$SUT" "$img" >/dev/null 2>&1
check "image records path"  "$img"   "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"
check "image records kind"  "image"  "$(cat "$WP_STATE_DIR/kind" 2>/dev/null)"
# Count 'awww img' specifically: apply_image() also runs 'awww query' to probe
# for a live daemon, so a stub logging every call records two lines.
check "image used awww img" "1"      "$(grep -c '^awww img' "$work/calls" 2>/dev/null || echo 0)"

"$SUT" "$vid" >/dev/null 2>&1
check "video records kind"  "video"  "$(cat "$WP_STATE_DIR/kind" 2>/dev/null)"
check "video used mpvpaper" "1"      "$(grep -c '^mpvpaper ' "$work/calls" 2>/dev/null || echo 0)"

check "--current prints path" "$vid" "$("$SUT" --current)"

: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1
check "restore reapplied video" "1" "$(grep -c '^mpvpaper ' "$work/calls" 2>/dev/null || echo 0)"

# ── Sound ──────────────────────────────────────────────────────────────────
# The video and follower are backgrounded, so give them a moment to log.
settle() { sleep 0.2; }

: > "$work/calls"
"$SUT" "$vid" >/dev/null 2>&1; settle
check "muted video records audio off" "off" "$(cat "$WP_STATE_DIR/audio" 2>/dev/null)"
check "muted video has no audio track" "1" "$(grep -c '^mpvpaper -o no-audio' "$work/calls" 2>/dev/null || echo 0)"
check "muted video starts no follower" "0" "$(grep -c '^follow ' "$work/calls" 2>/dev/null)"

: > "$work/calls"
"$SUT" "$vid" --sound >/dev/null 2>&1; settle
check "sound video records audio on"  "on" "$(cat "$WP_STATE_DIR/audio" 2>/dev/null)"
check "sound video starts muted with IPC" "1" \
  "$(grep -c "^mpvpaper -o loop mute=yes input-ipc-server=$work/wallpaper-picker-mpv-all.sock \\* " "$work/calls" 2>/dev/null || echo 0)"
check "sound video starts follower on the socket" "follow $work/wallpaper-picker-mpv-all.sock" "$(grep '^follow ' "$work/calls" 2>/dev/null)"
check "--current-audio prints on" "on" "$("$SUT" --current-audio)"

: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1; settle
check "restore keeps sound" "1" "$(grep -c '^mpvpaper -o loop mute=yes' "$work/calls" 2>/dev/null || echo 0)"
check "restore restarts follower" "1" "$(grep -c '^follow ' "$work/calls" 2>/dev/null || echo 0)"

"$SUT" "$img" --sound >/dev/null 2>&1
check "image ignores --sound" "off" "$(cat "$WP_STATE_DIR/audio" 2>/dev/null)"
check "--current-audio prints off" "off" "$("$SUT" --current-audio)"

# No socat: the follower could never unmute, so refuse rather than go silent,
# and leave the running wallpaper and its state alone.
"$SUT" "$vid" >/dev/null 2>&1; settle
: > "$work/calls"
SOCAT_BIN="$work/no-such-socat" "$SUT" "$vid" --sound >/dev/null 2>&1
check "sound without socat exits 1" "1" "$?"
check "sound without socat starts nothing" "" "$(cat "$work/calls")"
check "sound without socat keeps state" "off" "$(cat "$WP_STATE_DIR/audio" 2>/dev/null)"

"$SUT" "$vid" --loud >/dev/null 2>&1
check "unknown second arg exits 1" "1" "$?"

# State written before the audio file existed reads as muted.
rm -f "$WP_STATE_DIR/audio"
check "--current-audio defaults off" "off" "$("$SUT" --current-audio)"

# ── Per monitor ────────────────────────────────────────────────────────────
printf '[{"name":"eDP-1","focused":false},{"name":"HDMI-A-1","focused":true}]' > "$work/monitors.json"
vid2="$work/other.webm"; : > "$vid2"
mstate() { cat "$WP_STATE_DIR/outputs/$1/$2" 2>/dev/null; }

: > "$work/calls"
"$SUT" "$img" >/dev/null 2>&1
check "no --output targets focused monitor" "$img" "$(mstate HDMI-A-1 current)"
check "image only on that monitor" "1" "$(grep -c '^awww img -o HDMI-A-1 ' "$work/calls" 2>/dev/null || echo 0)"
check "other monitor untouched" "" "$(mstate eDP-1 current)"

: > "$work/calls"
"$SUT" --output eDP-1 "$vid2" --sound >/dev/null 2>&1; settle
check "--output records under that monitor" "$vid2" "$(mstate eDP-1 current)"
check "--output records its audio" "on" "$(mstate eDP-1 audio)"
check "video plays only on that monitor" "1" \
  "$(grep -c "^mpvpaper -o loop mute=yes input-ipc-server=$work/wallpaper-picker-mpv-eDP-1.sock eDP-1 $vid2" "$work/calls" 2>/dev/null || echo 0)"
check "follower watches that monitor" "follow $work/wallpaper-picker-mpv-eDP-1.sock eDP-1" "$(grep '^follow ' "$work/calls")"
check "focused monitor kept its wallpaper" "$img" "$(mstate HDMI-A-1 current)"

check "--current is per monitor (focused)" "$img"  "$("$SUT" --current)"
check "--current is per monitor (--output)" "$vid2" "$("$SUT" --output eDP-1 --current)"
check "--current-audio is per monitor" "off on" \
  "$("$SUT" --current-audio) $("$SUT" --current-audio --output eDP-1)"

: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1; settle
check "restore: image back on its monitor" "1" "$(grep -c '^awww img -o HDMI-A-1 .*pic.png' "$work/calls" 2>/dev/null || echo 0)"
check "restore: video back on its monitor" "1" "$(grep -c "^mpvpaper .* eDP-1 $vid2" "$work/calls" 2>/dev/null || echo 0)"
check "restore: sound kept per monitor" "1" "$(grep -c '^follow .* eDP-1$' "$work/calls" 2>/dev/null || echo 0)"

# A monitor with nothing of its own falls back to the old every-monitor state.
printf '[{"name":"DP-9","focused":true}]' > "$work/monitors.json"
printf '%s' "$img" > "$WP_STATE_DIR/current"
printf 'image' > "$WP_STATE_DIR/kind"
check "new monitor inherits old state" "$img" "$("$SUT" --current)"

# An every-monitor apply (monitor unknown) overrides every monitor's own.
rm -f "$work/monitors.json"
"$SUT" "$img" >/dev/null 2>&1
check "unknown-monitor apply clears per-monitor state" "0" \
  "$([ -d "$WP_STATE_DIR/outputs" ] && echo 1 || echo 0)"

"$SUT" --output >/dev/null 2>&1
check "--output without a name exits 1" "1" "$?"

"$SUT" "$work/missing.png" >/dev/null 2>&1
check "missing file exits 1" "1" "$?"

# Test cold daemon case: awww query fails (non-zero) but img succeeds.
# Create daemon stub and a stub that fails on 'query' but succeeds on 'img'.
printf '#!/usr/bin/env bash\necho "awww-daemon" >> "%s/calls"\n' "$work" > "$AWWW_BIN-daemon"
chmod +x "$AWWW_BIN-daemon"
printf '#!/usr/bin/env bash\nif [ "$1" = query ]; then exit 1; fi\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"
: > "$work/calls"
"$SUT" "$img" >/dev/null 2>&1
check "cold daemon starts daemon" "1" "$(grep -c '^awww-daemon' "$work/calls" 2>/dev/null || echo 0)"
check "cold daemon applies image" "1" "$(grep -c '^awww img' "$work/calls" 2>/dev/null || echo 0)"

# Reset stubs to always succeed
rm -f "$AWWW_BIN-daemon"
printf '#!/usr/bin/env bash\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"

# Test unsupported extension exits 1 and writes no state
unsupported="$work/file.txt"
: > "$unsupported"
rm -f "$WP_STATE_DIR/current" "$WP_STATE_DIR/kind"
"$SUT" "$unsupported" >/dev/null 2>&1
check "unsupported exits 1" "1" "$?"
check "unsupported writes no state" "" "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"

# Test failing awww img exits 1 and writes no state
# Create stub that always fails on img
printf '#!/usr/bin/env bash\nif [ "$1" = img ]; then exit 1; fi\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"
rm -f "$WP_STATE_DIR/current" "$WP_STATE_DIR/kind"
"$SUT" "$img" >/dev/null 2>&1
check "failing awww img exits 1" "1" "$?"
check "failing awww img writes no state" "" "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"

# --restore with no state: exits 0, writes nothing, still starts awww (first login must not be blank).
rm -f "$WP_STATE_DIR/current" "$WP_STATE_DIR/kind"
printf '#!/usr/bin/env bash\necho "awww-daemon" >> "%s/calls"\n' "$work" > "$AWWW_BIN-daemon"
chmod +x "$AWWW_BIN-daemon"
printf '#!/usr/bin/env bash\nif [ "$1" = query ]; then exit 1; fi\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"
: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1
check "restore no-state exits 0"       "0"  "$?"
check "restore no-state writes no state" "" "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"
check "restore no-state starts daemon" "1"  "$(grep -c '^awww-daemon' "$work/calls" 2>/dev/null || echo 0)"

# --restore with state naming a missing file: same, and the stale state is left untouched.
printf '%s' "$work/gone.png" > "$WP_STATE_DIR/current"
: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1
check "restore stale-path exits 0"        "0"             "$?"
check "restore stale-path leaves state"   "$work/gone.png" "$(cat "$WP_STATE_DIR/current" 2>/dev/null)"
check "restore stale-path starts daemon"  "1"             "$(grep -c '^awww-daemon' "$work/calls" 2>/dev/null || echo 0)"

rm -f "$AWWW_BIN-daemon"
printf '#!/usr/bin/env bash\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"

# --restore with a failing `awww img`: must still fall back to starting the daemon and exit 0.
# The stub's query gates on the daemon's marker file, so the daemon starts exactly once.
printf '%s' "$img" > "$WP_STATE_DIR/current"
printf 'image' > "$WP_STATE_DIR/kind"
rm -f "$work/daemon-marker"
printf '#!/usr/bin/env bash\ntouch "%s/daemon-marker"\necho "awww-daemon" >> "%s/calls"\n' \
  "$work" "$work" > "$AWWW_BIN-daemon"
chmod +x "$AWWW_BIN-daemon"
printf '#!/usr/bin/env bash\nif [ "$1" = query ]; then [ -f "%s/daemon-marker" ] && exit 0 || exit 1; fi\nif [ "$1" = img ]; then exit 1; fi\necho "awww $*" >> "%s/calls"\n' \
  "$work" "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"
: > "$work/calls"
"$SUT" --restore >/dev/null 2>&1
check "restore failing-apply exits 0"       "0" "$?"
check "restore failing-apply starts daemon" "1" "$(grep -c '^awww-daemon' "$work/calls" 2>/dev/null || echo 0)"

rm -f "$AWWW_BIN-daemon" "$work/daemon-marker"
printf '#!/usr/bin/env bash\necho "awww $*" >> "%s/calls"\n' "$work" > "$AWWW_BIN"
chmod +x "$AWWW_BIN"

if [ "$fails" -eq 0 ]; then echo "ALL PASS"; exit 0; else echo "FAILURES=$fails"; exit 1; fi
