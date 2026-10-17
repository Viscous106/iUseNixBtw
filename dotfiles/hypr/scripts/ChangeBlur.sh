#!/run/current-system/sw/bin/bash
# Toggle light/normal blur (SUPER+ALT+O). The Lua parser rejects `hyprctl keyword`,
# so options go through `hyprctl eval`.
notif="$HOME/.config/hypr/icons"

# Normal values must match lua/decorations.lua.
NORMAL_SIZE=6
NORMAL_PASSES=2
LIGHT_SIZE=2
LIGHT_PASSES=1

set_blur() {
	# eval exits non-zero on failure; check it so a rejected change isn't silent.
	if ! hyprctl eval "hl.config({ decoration = { blur = { size = $1, passes = $2 } } })" >/dev/null; then
		notify-send -e -u critical " Blur toggle failed" "hyprctl eval rejected size=$1 passes=$2"
		exit 1
	fi
}

STATE=$(hyprctl -j getoption decoration:blur:passes | jq ".int")

if [ "${STATE}" == "$NORMAL_PASSES" ]; then
	set_blur "$LIGHT_SIZE" "$LIGHT_PASSES"
	notify-send -e -u low -i "$notif/note.png" " Less Blur"
else
	set_blur "$NORMAL_SIZE" "$NORMAL_PASSES"
	notify-send -e -u low -i "$notif/ja.png" " Normal Blur"
fi
