#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# For Searching via web browsers

# Shell defaults — mirrors lua/user_defaults.lua (see configs/user-defaults.sh)
source "$HOME/.config/hypr/configs/user-defaults.sh"

# Check if $term is set correctly
if [[ -z "$Search_Engine" ]]; then
    echo "Error: \$Search_Engine is not set in the configuration file!"
    exit 1
fi

# Rofi theme and message
rofi_theme="$HOME/.config/rofi/config-search.rasi"
msg='‼️ **note** ‼️ search via default web browser'

# Kill Rofi if already running before execution
if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

# Open Rofi and pass the selected query to xdg-open for Google search
echo "" | rofi -dmenu -config "$rofi_theme" -mesg "$msg" | xargs -I{} xdg-open $Search_Engine