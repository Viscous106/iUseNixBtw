#!/run/current-system/sw/bin/bash
# Web search from rofi via the default browser.

Search_Engine="https://www.google.com/search?q={}"

rofi_theme="$HOME/.config/rofi/config-search.rasi"
msg='‼️ **note** ‼️ search via default web browser'

if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

echo "" | rofi -dmenu -config "$rofi_theme" -mesg "$msg" | xargs -I{} xdg-open $Search_Engine