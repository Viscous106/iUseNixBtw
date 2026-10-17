#!/run/current-system/sw/bin/bash
# hyprlock with the focused monitor's current wallpaper as background (SUPER+L).
# ~/.config/hypr/hyprlock.conf is a read-only store file, so a copy with the
# path swapped in is written to $XDG_RUNTIME_DIR and passed with -c.

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
