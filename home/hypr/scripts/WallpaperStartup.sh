#!/usr/bin/env bash
# Set a random wallpaper on all monitors at Hyprland startup

wallDIR="$HOME/Pictures/wallpapers"

# Wait for awww-daemon to be ready (up to 10 seconds)
for i in $(seq 1 20); do
    awww query &>/dev/null && break
    sleep 0.5
done

# Gather all wallpaper images recursively
mapfile -t PICS < <(find -L "$wallDIR" -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
    -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" \
\))

if [[ ${#PICS[@]} -eq 0 ]]; then
    echo "No wallpapers found in $wallDIR"
    exit 1
fi

# Transition config
FPS=30
TYPE="random"
DURATION=1
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --transition-bezier $BEZIER"

# Set a random wallpaper on every connected monitor
mapfile -t MONITORS < <(hyprctl -j monitors | jq -r '.[].name')

for monitor in "${MONITORS[@]}"; do
    RANDOMPIC="${PICS[$RANDOM % ${#PICS[@]}]}"
    awww img -o "$monitor" "$RANDOMPIC" $SWWW_PARAMS
    # Save last wallpaper for swaylock / lockscreen
    mkdir -p "$HOME/.config/hypr/configs/wallpaper_effects"
    echo "$RANDOMPIC" > "$HOME/.config/hypr/configs/wallpaper_effects/.wallpaper_current"
done
