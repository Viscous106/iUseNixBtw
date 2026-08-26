#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
# Waybar modules source shell defaults (term / files / edit / Search_Engine).

# Shell defaults — mirrors lua/user_defaults.lua (see configs/user-defaults.sh)
source "$HOME/.config/hypr/configs/user-defaults.sh"

# Check if $term is set correctly
if [[ -z "$term" ]]; then
    echo "Error: \$term is not set in the configuration file!"
    exit 1
fi

# Execute accordingly based on the passed argument
if [[ "$1" == "--btop" ]]; then
    $term --title btop sh -c 'btop'
elif [[ "$1" == "--nvtop" ]]; then
    $term --title nvtop sh -c 'nvtop'
elif [[ "$1" == "--nmtui" ]]; then
    $term nmtui
elif [[ "$1" == "--term" ]]; then
    $term &
elif [[ "$1" == "--files" ]]; then
    $files &
else
    echo "Usage: $0 [--btop | --nvtop | --nmtui | --term]"
    echo "--btop       : Open btop in a new term"
    echo "--nvtop      : Open nvtop in a new term"
    echo "--nmtui      : Open nmtui in a new term"
    echo "--term   : Launch a term window"
    echo "--files  : Launch a file manager"
fi