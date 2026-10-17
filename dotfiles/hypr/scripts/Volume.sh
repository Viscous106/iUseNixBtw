#!/run/current-system/sw/bin/bash
# Speaker and mic volume via pamixer.

iDIR="$HOME/.config/hypr/icons"
sDIR="$HOME/.config/hypr/scripts"

get_volume() {
    volume=$(pamixer --get-volume)
    if [[ "$(pamixer --get-mute)" == "true" || "$volume" -eq "0" ]]; then
        echo "Muted"
    else
        echo "$volume %"
    fi
}

get_icon() {
    current=$(get_volume)
    if [[ "$current" == "Muted" ]]; then
        echo "$iDIR/volume-mute.png"
    elif [[ "${current%\%}" -le 30 ]]; then
        echo "$iDIR/volume-low.png"
    elif [[ "${current%\%}" -le 60 ]]; then
        echo "$iDIR/volume-mid.png"
    else
        echo "$iDIR/volume-high.png"
    fi
}

# No notification: caelestia's OSD reads PipeWire directly. Keep the feedback sound.
notify_user() {
    if [[ "$(get_volume)" != "Muted" ]]; then
        "$sDIR/Sounds.sh" --volume
    fi
}

inc_volume() {
    if [ "$(pamixer --get-mute)" == "true" ]; then
        toggle_mute
    else
        pamixer -i 5 --allow-boost --set-limit 150 && notify_user
    fi
}

dec_volume() {
    if [ "$(pamixer --get-mute)" == "true" ]; then
        toggle_mute
    else
        pamixer -d 5 && notify_user
    fi
}

toggle_mute() {
	if [ "$(pamixer --get-mute)" == "false" ]; then
		pamixer -m
	elif [ "$(pamixer --get-mute)" == "true" ]; then
		pamixer -u
	fi
}

toggle_mic() {
	if [ "$(pamixer --default-source --get-mute)" == "true" ]; then
		pamixer --default-source -u
		# The default source changes with headsets, so unmute every real source too.
		for _src in $(pactl list short sources | awk '$2 !~ /\.monitor$/ { print $2 }'); do
			pactl set-source-mute "$_src" 0 2>/dev/null
		done
	else
		pamixer --default-source -m
	fi
}
get_mic_icon() {
    if [[ "$(pamixer --default-source --get-mute)" == "true" ]]; then
        echo "$iDIR/microphone-mute.png"
    else
        echo "$iDIR/microphone.png"
    fi
}

get_mic_volume() {
    volume=$(pamixer --default-source --get-volume)
    if [[ "$(pamixer --default-source --get-mute)" == "true" || "$volume" -eq "0" ]]; then
        echo "Muted"
    else
        echo "$volume %"
    fi
}

# No-op, see notify_user.
notify_mic_user() {
    :
}

inc_mic_volume() {
    if [ "$(pamixer --default-source --get-mute)" == "true" ]; then
        toggle_mic
    else
        pamixer --default-source -i 5 && notify_mic_user
    fi
}

dec_mic_volume() {
    if [ "$(pamixer --default-source --get-mute)" == "true" ]; then
        toggle_mic
    else
        pamixer --default-source -d 5 && notify_mic_user
    fi
}

if [[ "$1" == "--get" ]]; then
	get_volume
elif [[ "$1" == "--inc" ]]; then
	inc_volume
elif [[ "$1" == "--dec" ]]; then
	dec_volume
elif [[ "$1" == "--toggle" ]]; then
	toggle_mute
elif [[ "$1" == "--toggle-mic" ]]; then
	toggle_mic
elif [[ "$1" == "--get-icon" ]]; then
	get_icon
elif [[ "$1" == "--get-mic-icon" ]]; then
	get_mic_icon
elif [[ "$1" == "--get-mic" || "$1" == "--get-mic-volume" ]]; then
	get_mic_volume
elif [[ "$1" == "--mic-inc" ]]; then
	inc_mic_volume
elif [[ "$1" == "--mic-dec" ]]; then
	dec_mic_volume
else
	get_volume
fi