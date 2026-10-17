#!/run/current-system/sw/bin/bash
# Apply an ImageMagick effect to the focused monitor's wallpaper (SUPER+SHIFT+W).
# Reads the original from wallpaper-picker's state, so effects never stack, and
# writes the result to a cache file rather than touching the picker's state.

state="$HOME/.local/state/wallpaper-picker"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-effects"
icon="$HOME/.config/swaync/images/ja.png"
rofi_theme="$HOME/.config/rofi/config-wallpaper-effect.rasi"
transition=(--transition-type wipe --transition-duration 2 --transition-fps 60 --transition-bezier .43,1.19,1,.4)

mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

# Per-monitor state, falling back to the every-monitor state (same rule as apply.sh).
read_state() {
  if [ -f "$state/outputs/$mon/$1" ]; then cat "$state/outputs/$mon/$1"; else cat "$state/$1" 2>/dev/null; fi
}
src=$(read_state current)
if [ "$(read_state kind)" != image ] || [ ! -f "$src" ]; then
  notify-send -u low -i "$icon" "Wallpaper effects" "Only works on image wallpapers"
  exit 1
fi

mkdir -p "$cache"
out="$cache/$mon.png"
ln -sf "$src" "$cache/preview.png"  # rofi menu background (config-wallpaper-effect.rasi)

declare -A effects=(
  ["Black & White"]="-colorspace gray -sigmoidal-contrast 10,40%"
  ["Blurred"]="-blur 0x10"
  ["Charcoal"]="-charcoal 0x5"
  ["Edge Detect"]="-edge 1"
  ["Emboss"]="-emboss 0x5"
  ["Frame Raised"]="+raise 150"
  ["Frame Sunk"]="-raise 150"
  ["Negate"]="-negate"
  ["Oil Paint"]="-paint 4"
  ["Posterize"]="-posterize 4"
  ["Polaroid"]="-polaroid 0"
  ["Sepia Tone"]="-sepia-tone 65%"
  ["Solarize"]="-solarize 80%"
  ["Sharpen"]="-sharpen 0x5"
  ["Vignette"]="-vignette 0x3"
  ["Vignette-black"]="-background black -vignette 0x3"
  ["Zoomed"]="-gravity Center -extent 1:1"
)

pkill rofi
choice=$( { echo "No Effects"; printf '%s\n' "${!effects[@]}" | LC_COLLATE=C sort; } \
  | rofi -dmenu -i -config "$rofi_theme")
[ -n "$choice" ] || exit 0

if [ "$choice" = "No Effects" ]; then
  awww img -o "$mon" "$src" "${transition[@]}"
  notify-send -u low -i "$icon" "No wallpaper" "effects applied"
  exit 0
fi

[ -n "${effects[$choice]}" ] || exit 1
notify-send -u normal -i "$icon" "Applying:" "$choice effects"
# shellcheck disable=SC2086  # effect args are intentionally word-split
magick "$src" ${effects[$choice]} "$out" || exit 1
pkill -SIGUSR1 -f mpvpaper  # pause a video wallpaper underneath, if any
awww img -o "$mon" "$out" "${transition[@]}"
notify-send -u low -i "$icon" "$choice" "effects applied"
