#!/run/current-system/sw/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Toggle the touchpad. Bound to xf86TouchpadToggle in lua/laptops.lua.
#
# WHY `hyprctl eval` AND NOT `hyprctl keyword` — same reason as ChangeBlur.sh.
# This one was broken twice over: it set `$TOUCHPAD_ENABLED`, a variable that
# only ever existed in the old legacy configs/Laptops.conf. The Lua config has
# no such variable, so even a working `keyword` would have had nothing to set.
#
# The device name is detected at runtime rather than hardcoded. lua/laptops.lua
# names "elan-touchpad", but `hyprctl devices` reports the real device as
# asuf1204:00-2808:0202-touchpad — and hl.device() accepts an unknown name and
# returns ok, so a wrong name fails silently with no way to notice.

notif="$HOME/.config/swaync/images/ja.png"
STATUS_FILE="$XDG_RUNTIME_DIR/touchpad.status"

DEVICE=$(hyprctl devices | grep -oE "[a-z0-9:_.-]+-touchpad" | head -1)
if [ -z "$DEVICE" ]; then
	notify-send -e -u critical " Touchpad toggle failed" "no touchpad found in hyprctl devices"
	exit 1
fi

set_touchpad() {
	if ! hyprctl eval "hl.device({ name = \"$DEVICE\", enabled = $1 })" >/dev/null; then
		notify-send -e -u critical " Touchpad toggle failed" "hyprctl eval rejected enabled=$1"
		exit 1
	fi
	printf "%s" "$1" >"$STATUS_FILE"
}

# No status file means nothing has toggled since boot, and the device comes up
# enabled — so the first press must DISABLE. The old script enabled instead,
# which made the first press after every boot do nothing at all.
if [ "$(cat "$STATUS_FILE" 2>/dev/null)" = "false" ]; then
	set_touchpad true
	notify-send -e -u low -i "$notif" " Enabling" " touchpad"
else
	set_touchpad false
	notify-send -e -u low -i "$notif" " Disabling" " touchpad"
fi
