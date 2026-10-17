#!/run/current-system/sw/bin/bash
# Toggle wl-kbptr (keyboard-driven pointer); $1 is the click button.
BUTTON=${1:-left}

if pgrep -x "wl-kbptr" > /dev/null
then
    pkill -x "wl-kbptr"
else
    wl-kbptr -o modes=tile,bisect,click -o mode_click.button="$BUTTON"
fi