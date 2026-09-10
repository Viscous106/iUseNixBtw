#!/run/current-system/sw/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# for changing Hyprland Layouts (Master or Dwindle) on the fly
#
# WHY `hyprctl eval` AND NOT `hyprctl keyword` — same reason as ChangeBlur.sh.
# This config is Lua, so Hyprland runs its non-legacy parser, which refuses
# keyword ("keyword can't work with non-legacy parsers. Use eval."). hyprctl
# still exited 0 and the notification still fired, so this bind reported a
# layout change on every press while changing nothing.

notif="$HOME/.config/swaync/images/ja.png"

hypr_eval() {
	# eval exits 7 and prints "error: ..." on failure. Checking it is the point:
	# unchecked success is what hid this for so long.
	if ! hyprctl eval "$1" >/dev/null; then
		notify-send -e -u critical " Layout toggle failed" "hyprctl eval rejected: $1"
		exit 1
	fi
}

LAYOUT=$(hyprctl -j getoption general:layout | jq -r '.str')

case $LAYOUT in
"master")
	hypr_eval 'hl.config({ general = { layout = "dwindle" } })'
	# togglesplit only means anything under dwindle, so the bind tracks the layout.
	hypr_eval 'hl.bind("SUPER + O", hl.dsp.layout("togglesplit"))'
	notify-send -e -u low -i "$notif" " Dwindle Layout"
	;;
"dwindle")
	hypr_eval 'hl.config({ general = { layout = "master" } })'
	hypr_eval 'hl.unbind("SUPER + O")'
	notify-send -e -u low -i "$notif" " Master Layout"
	;;
*) ;;
esac
