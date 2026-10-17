#!/run/current-system/sw/bin/bash
# Toggle master/dwindle layout. Uses `hyprctl eval`: the Lua parser rejects `keyword`.

notif="$HOME/.config/hypr/icons/ja.png"

hypr_eval() {
	# eval exits non-zero on failure; check it so a rejected change isn't silent.
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
