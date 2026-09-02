#!/run/current-system/sw/bin/bash
# Restore the last-used wallpaper at Hyprland startup.
# Replaces the old Startup_Apps.conf swww/mpvpaper exec-once toggle. Run from
# lua/startup_apps.lua on hyprland.start. State is written by WallpaperSelect.sh.
#
#   live_state non-empty -> live (video) wallpaper: run mpvpaper on each monitor
#   live_state empty/absent -> static image: run awww-daemon (restores its cached image)

live_state="$HOME/.config/hypr/configs/wallpaper_effects/.live_wallpaper"

start_awww() {
  # awww-daemon is a makeWrapper stub on NixOS, so its live kernel comm isn't
  # "awww-daemon" -- use `awww query` to detect a live daemon instead of an
  # exact-name pgrep.
  awww query &>/dev/null || awww-daemon &
}

if [ -s "$live_state" ]; then
  video="$(head -n1 "$live_state")"
  video="${video/#\$HOME/$HOME}"   # expand a stored $HOME prefix
  video="${video/#\~/$HOME}"
  if [ -n "$video" ] && [ -f "$video" ] && command -v mpvpaper >/dev/null; then
    # mpvpaper is a makeWrapper stub too -- `pkill -x` matches comm, which is
    # wrong here; match the full cmdline instead.
    pkill -f 'mpvpaper' 2>/dev/null
    for m in $(hyprctl -j monitors 2>/dev/null | jq -r '.[].name'); do
      mpvpaper -o "no-audio --loop" "$m" "$video" &
    done
    exit 0
  fi
fi

# static image mode (or missing/invalid live wallpaper)
start_awww
