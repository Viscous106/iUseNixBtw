#!/run/current-system/sw/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Script for changing blurs on the fly — bound to SUPER+ALT+O in lua/keybinds.lua
#
# WHY `hyprctl eval` AND NOT `hyprctl keyword`
# This config is Lua (hyprland.lua + lua/*.lua), so Hyprland runs its
# non-legacy parser, and that parser refuses keyword outright:
#
#   keyword can't work with non-legacy parsers. Use eval.
#
# hyprctl still exited 0 and the notification still fired, so the bind looked
# like it worked while changing nothing at all. `eval` runs Lua against the
# live config, where hl.config() takes the same table lua/decorations.lua uses.
#
# ChangeLayout.sh and TouchPad.sh had the same bug and were converted alongside
# this one. The rest of the affected scripts (cursor_selector, KeybindsLayoutInit,
# GameMode, monitor_connect, mirror_connectToPhone) were deleted as unwanted
# rather than fixed, along with the binds and menu entries that called them.

notif="$HOME/.config/swaync/images"

# The normal values must track lua/decorations.lua. The previous version
# restored size 5 against a configured 6, so the first toggle cycle quietly
# walked the blur down and never put it back.
NORMAL_SIZE=6
NORMAL_PASSES=2
LIGHT_SIZE=2
LIGHT_PASSES=1

set_blur() {
	# eval exits 7 and prints "error: ..." on failure. Checking it is the whole
	# point: silent success is what hid this bug in the first place.
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
