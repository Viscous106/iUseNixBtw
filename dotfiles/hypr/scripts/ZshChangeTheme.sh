#!/run/current-system/sw/bin/bash
# Oh My Zsh theme picker (CTRL SHIFT O); new terminals pick up the change.

iDIR="$HOME/.config/hypr/icons"
rofi_theme="$HOME/.config/rofi/config-zsh-theme.rasi"

if [ -n "$(grep -i nixos < /etc/os-release)" ]; then
  notify-send -i "$iDIR/note.png" "NOT Supported" "Sorry NixOS does not support this KooL feature"
  exit 1
fi

themes_dir="$HOME/.oh-my-zsh/themes"
file_extension=".zsh-theme"


themes_array=($(find -L "$themes_dir" -type f -name "*$file_extension" -exec basename {} \; | sed -e "s/$file_extension//"))

themes_array=("Random" "${themes_array[@]}")

rofi_command="rofi -i -dmenu -config $rofi_theme"

menu() {
    for theme in "${themes_array[@]}"; do
        echo "$theme"
    done
}

main() {
    choice=$(menu | ${rofi_command})

    if [ -z "$choice" ]; then
        exit 0
    fi

    zsh_path="$HOME/.zshrc"
    var_name="ZSH_THEME"

    if [[ "$choice" == "Random" ]]; then
        # Index 0 is "Random" itself, so skip it.
        random_theme=${themes_array[$((RANDOM % (${#themes_array[@]} - 1) + 1))]}
        theme_to_set="$random_theme"
        notify-send -i "$iDIR/ja.png" "Random theme:" "selected: $random_theme"
    else
        theme_to_set="$choice"
        notify-send -i "$iDIR/ja.png" "Theme selected:" "$choice"
    fi

    if [ -f "$zsh_path" ]; then
        sed -i "s/^$var_name=.*/$var_name=\"$theme_to_set\"/" "$zsh_path"
        notify-send -i "$iDIR/ja.png" "OMZ theme" "applied. restart your terminal"
    else
        notify-send -i "$iDIR/error.png" "E-R-R-O-R" "~.zshrc file not found!"
    fi
}

if pidof rofi > /dev/null; then
  pkill rofi
fi

main
