#!/run/current-system/sw/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Scripts for volume controls for audio and mic 

iDIR="$HOME/.config/swaync/icons"
sDIR="$HOME/.config/hypr/scripts"

# Get Volume
get_volume() {
    volume=$(pamixer --get-volume)
    if [[ "$(pamixer --get-mute)" == "true" || "$volume" -eq "0" ]]; then
        echo "Muted"
    else
        echo "$volume %"
    fi
}

# Get icons
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

# Feedback
# The notify-send calls that used to live here are gone. They relied on
# x-canonical-private-synchronous:volume_notif, a swaync extension that made
# each new popup REPLACE the previous one. Caelestia implements no equivalent
# (nothing in Notifs.qml/NotifData.qml reads that hint), so every keypress
# stacked another permanent notification instead of updating one.
# Caelestia's OSD reads PipeWire directly — Connections { target: Audio } in
# modules/osd/Wrapper.qml — so the level is displayed regardless of who changed
# it. The volume feedback sound is kept.
notify_user() {
    if [[ "$(get_volume)" != "Muted" ]]; then
        "$sDIR/Sounds.sh" --volume
    fi
}

# Increase Volume
inc_volume() {
    if [ "$(pamixer --get-mute)" == "true" ]; then
        toggle_mute
    else
        pamixer -i 5 --allow-boost --set-limit 150 && notify_user
    fi
}

# Decrease Volume
dec_volume() {
    if [ "$(pamixer --get-mute)" == "true" ]; then
        toggle_mute
    else
        pamixer -d 5 && notify_user
    fi
}

# Toggle Mute
toggle_mute() {
	if [ "$(pamixer --get-mute)" == "false" ]; then
		pamixer -m
	elif [ "$(pamixer --get-mute)" == "true" ]; then
		pamixer -u
	fi
}

# Toggle Mic
toggle_mic() {
	if [ "$(pamixer --default-source --get-mute)" == "true" ]; then
		pamixer --default-source -u
		# The default source changes when a headset connects or drops, so a mute
		# applied to one device could never be lifted from another. Clear mute on
		# every real (non-monitor) source so the key always actually turns the
		# microphone back on.
		for _src in $(pactl list short sources | awk '$2 !~ /\.monitor$/ { print $2 }'); do
			pactl set-source-mute "$_src" 0 2>/dev/null
		done
	else
		pamixer --default-source -m
	fi
}
# Get Mic Icon
get_mic_icon() {
    if [[ "$(pamixer --default-source --get-mute)" == "true" ]]; then
        echo "$iDIR/microphone-mute.png"
    else
        echo "$iDIR/microphone.png"
    fi
}

# Get Microphone Volume
get_mic_volume() {
    volume=$(pamixer --default-source --get-volume)
    if [[ "$(pamixer --default-source --get-mute)" == "true" || "$volume" -eq "0" ]]; then
        echo "Muted"
    else
        echo "$volume %"
    fi
}

# Notify for Microphone — see notify_user above for why this is now a no-op.
notify_mic_user() {
    :
}

# Increase MIC Volume
inc_mic_volume() {
    if [ "$(pamixer --default-source --get-mute)" == "true" ]; then
        toggle_mic
    else
        pamixer --default-source -i 5 && notify_mic_user
    fi
}

# Decrease MIC Volume
dec_mic_volume() {
    if [ "$(pamixer --default-source --get-mute)" == "true" ]; then
        toggle_mic
    else
        pamixer --default-source -d 5 && notify_mic_user
    fi
}

# Execute accordingly
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
	# get_mic_volume was defined but had no dispatch case, so asking for the mic
	# level fell through to the final `else` and returned the SPEAKER volume.
	get_mic_volume
elif [[ "$1" == "--mic-inc" ]]; then
	inc_mic_volume
elif [[ "$1" == "--mic-dec" ]]; then
	dec_mic_volume
else
	get_volume
fi