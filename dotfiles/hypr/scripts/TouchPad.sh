#!/run/current-system/sw/bin/bash
# Toggle the touchpad (xf86TouchpadToggle). The device name is detected because
# hl.device() silently accepts a wrong one.

notif="$HOME/.config/hypr/icons/ja.png"
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

# No status file = untouched since boot = enabled, so the first press disables.
if [ "$(cat "$STATUS_FILE" 2>/dev/null)" = "false" ]; then
	set_touchpad true
	notify-send -e -u low -i "$notif" " Enabling" " touchpad"
else
	set_touchpad false
	notify-send -e -u low -i "$notif" " Disabling" " touchpad"
fi
