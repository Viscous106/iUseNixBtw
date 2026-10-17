#!/run/current-system/sw/bin/bash
# Screen recording with wf-recorder: pick a target, then the audio source.

notify() {
    notify-send "Screen Recorder" "$1" -u low
}

# wf-recorder takes one audio device, so "System + Mic" needs a temporary mix sink;
# module ids are saved so stop can tear it down.
mix_state="${XDG_RUNTIME_DIR:-/tmp}/screenrec-mix-modules"
mix_sink="screenrec_mix"

teardown_mix() {
    [ -f "$mix_state" ] || return 0
    # Unload in reverse order: loopbacks first, then the sink they feed.
    tac "$mix_state" | while read -r id; do
        pactl unload-module "$id" 2>/dev/null
    done
    rm -f "$mix_state"
}

setup_mix() {
    teardown_mix
    local sys_monitor mic
    sys_monitor="$(pactl get-default-sink).monitor"
    mic="$(pactl get-default-source)"
    {
        pactl load-module module-null-sink sink_name="$mix_sink" \
            sink_properties=device.description=ScreenRecord-Mix
        pactl load-module module-loopback source="$sys_monitor" sink="$mix_sink" latency_msec=20
        pactl load-module module-loopback source="$mic" sink="$mix_sink" latency_msec=20
    } > "$mix_state"
}

if pgrep -x "wf-recorder" > /dev/null; then
    killall -s SIGINT wf-recorder
    # Let wf-recorder finish writing before pulling its audio source away.
    for _ in $(seq 50); do
        pgrep -x "wf-recorder" > /dev/null || break
        sleep 0.1
    done
    teardown_mix
    notify "Recording stopped. Video saved to ~/Videos."
    exit 0
fi

# Leftover mix from a recording that died without going through the stop branch
teardown_mix

options="󰍹 Full Screen\n󰖵 Active Window\n󰩬 Select Region"

chosen_option=$(echo -e "$options" | rofi -dmenu -p "REC" -i)

if [ -z "$chosen_option" ]; then
    exit 0
fi

audio_options="󰕾 System Audio\n󰍬 Microphone\n󰋎 System + Mic\n󰖁 No Audio"
chosen_audio=$(echo -e "$audio_options" | rofi -dmenu -p "AUDIO" -i)

if [ -z "$chosen_audio" ]; then
    exit 0
fi

case "$chosen_audio" in
    "󰕾 System Audio")
        audio_args=(--audio="$(pactl get-default-sink).monitor")
        audio_label="system audio"
        ;;
    "󰍬 Microphone")
        audio_args=(--audio="$(pactl get-default-source)")
        audio_label="microphone"
        ;;
    "󰋎 System + Mic")
        audio_args=(--audio="$mix_sink.monitor")
        audio_label="system audio + microphone"
        ;;
    *)
        audio_args=()
        audio_label="no audio"
        ;;
esac

output_dir="$HOME/Videos"
output_file="$output_dir/recording_$(date +'%Y-%m-%d-%H%M%S').mp4"

mkdir -p "$output_dir"

# Work out the geometry for the chosen option (empty = full screen)
case "$chosen_option" in
    "󰍹 Full Screen")
        geometry_args=()
        target_label="full screen"
        ;;
    "󰖵 Active Window")
        geometry=$(hyprctl activewindow | grep "at:" | cut -d' ' -f2)
        size=$(hyprctl activewindow | grep "size:" | cut -d' ' -f2 | sed 's/,/x/')
        geometry_args=(-g "${geometry} ${size}")
        target_label="active window"
        ;;
    "󰩬 Select Region")
        # rope-select: animated slurp-compatible picker (dotfiles/quickshell/rope-select).
        geometry=$(rope-select)

        if [ -z "$geometry" ]; then
            notify "Recording cancelled."
            exit 0
        fi

        geometry_args=(-g "$geometry")
        target_label="selected region"
        ;;
    *)
        exit 0
        ;;
esac

# Build the mix only once nothing else can cancel the recording
if [ "$chosen_audio" = "󰋎 System + Mic" ]; then
    setup_mix
fi

notify "Starting $target_label recording ($audio_label)..."
wf-recorder "${audio_args[@]}" "${geometry_args[@]}" -f "$output_file" &> /dev/null &

# If wf-recorder dies straight away (bad device, etc.), say so and clean up
sleep 1
if ! pgrep -x "wf-recorder" > /dev/null; then
    teardown_mix
    notify "Recording failed to start."
fi
