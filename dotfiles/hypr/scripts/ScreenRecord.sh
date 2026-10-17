#!/run/current-system/sw/bin/bash

# A rofi-based script to easily manage screen recording with wf-recorder.
# Allows choosing between full screen, active window, or a selected region,
# then what audio to capture: system audio, microphone, both, or none.

# Function to display notifications
notify() {
    notify-send "Screen Recorder" "$1" -u low
}

# "System + Mic" needs a temporary PulseAudio/PipeWire mix sink, since
# wf-recorder only takes a single audio device. The module ids are kept here
# so the stop branch can tear the mix down again.
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

# Check if wf-recorder is already running
if pgrep -x "wf-recorder" > /dev/null; then
    # Stop the recording
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

# Rofi menu options
options="󰍹 Full Screen\n󰖵 Active Window\n󰩬 Select Region"

# Show Rofi menu and get user choice
chosen_option=$(echo -e "$options" | rofi -dmenu -p "REC" -i)

# Exit if no option is chosen
if [ -z "$chosen_option" ]; then
    exit 0
fi

# Ask what audio to capture
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

# Define the output file
output_dir="$HOME/Videos"
output_file="$output_dir/recording_$(date +'%Y-%m-%d-%H%M%S').mp4"

# Create output directory if it doesn't exist
mkdir -p "$output_dir"

# Work out the geometry for the chosen option (empty = full screen)
case "$chosen_option" in
    "󰍹 Full Screen")
        geometry_args=()
        target_label="full screen"
        ;;
    "󰖵 Active Window")
        # Get the geometry of the active window
        geometry=$(hyprctl activewindow | grep "at:" | cut -d' ' -f2)
        size=$(hyprctl activewindow | grep "size:" | cut -d' ' -f2 | sed 's/,/x/')
        geometry_args=(-g "${geometry} ${size}")
        target_label="active window"
        ;;
    "󰩬 Select Region")
        # Select a region using rope-select, the animated slurp-compatible
        # picker (dotfiles/quickshell/rope-select). It falls back to slurp on
        # its own if the overlay cannot run, and signals cancel the same way.
        geometry=$(rope-select)

        # Exit if the selection was cancelled
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
