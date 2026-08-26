#!/usr/bin/env bash
# Restore the last-used wallpaper at Hyprland startup.
# Replaces the old Startup_Apps.conf swww/mpvpaper exec-once toggle. Run from
# lua/startup_apps.lua on hyprland.start. State is written by WallpaperSelect.sh.
#
#   live_state non-empty -> live (video) wallpaper: run mpvpaper on each monitor
#   live_state empty/absent -> static image: run swww-daemon (restores its cached image)

live_state="$HOME/.config/hypr/configs/wallpaper_effects/.live_wallpaper"

start_swww() {
  pgrep -x swww-daemon >/dev/null || swww-daemon --format xrgb &
}

if [ -s "$live_state" ]; then
  video="$(head -n1 "$live_state")"
  video="${video/#\$HOME/$HOME}"   # expand a stored $HOME prefix
  video="${video/#\~/$HOME}"
  if [ -n "$video" ] && [ -f "$video" ] && command -v mpvpaper >/dev/null; then
    pkill -x mpvpaper 2>/dev/null
    for m in $(hyprctl -j monitors 2>/dev/null | jq -r '.[].name'); do
      mpvpaper -o "no-audio --loop" "$m" "$video" &
    done
    exit 0
  fi
fi

# static image mode (or missing/invalid live wallpaper)
start_swww
