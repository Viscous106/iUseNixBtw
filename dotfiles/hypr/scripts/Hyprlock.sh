#!/run/current-system/sw/bin/bash
# hyprlock with the focused monitor's wallpaper (SUPER+L). hyprlock.conf is a
# read-only store file, so a patched copy goes in $XDG_RUNTIME_DIR.

pidof hyprlock >/dev/null && exit 0

conf="$HOME/.config/hypr/hyprlock.conf"
runtime_conf="${XDG_RUNTIME_DIR:-/tmp}/hyprlock.conf"
state="$HOME/.local/state/wallpaper-picker"

mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name')
read_state() {
  if [ -f "$state/outputs/$mon/$1" ]; then cat "$state/outputs/$mon/$1"; else cat "$state/$1" 2>/dev/null; fi
}

wallpaper=$(read_state current)
# hyprlock cannot draw videos; keep hyprlock.conf's own default for those.
if [ "$(read_state kind)" = image ] && [ -f "$wallpaper" ]; then
  sed "s|^    path = .*|    path = $wallpaper|" "$conf" > "$runtime_conf"
  exec hyprlock -c "$runtime_conf"
fi
exec hyprlock
