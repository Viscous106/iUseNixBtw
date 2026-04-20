#!/usr/bin/env bash

# A rofi-based script to easily manage screen recording with wf-recorder.
# Allows choosing between full screen, active window, or a selected region.

# Function to display notifications
notify() {
    notify-send "Screen Recorder" "$1" -u low
}

# Check if wf-recorder is already running
if pgrep -x "wf-recorder" > /dev/null; then
    # Stop the recording
    killall -s SIGINT wf-recorder
    notify "Recording stopped. Video saved to ~/Videos."
    exit 0
fi

# Rofi menu options
options="󰍹 Full Screen\n󰖵 Active Window\n󰩬 Select Region"

# Show Rofi menu and get user choice
chosen_option=$(echo -e "$options" | rofi -dmenu -p "REC" -i)

# Exit if no option is chosen
if [ -z "$chosen_option" ]; then
    exit 0
fi

# Define the output file
output_dir="$HOME/Videos"
output_file="$output_dir/recording_$(date +'%Y-%m-%d-%H%M%S').mp4"

# Create output directory if it doesn't exist
mkdir -p "$output_dir"

# Start recording based on the chosen option
case "$chosen_option" in
    "󰍹 Full Screen")
        notify "Starting full screen recording..."
        wf-recorder -f "$output_file" &> /dev/null &
        ;;
    "󰖵 Active Window")
        # Get the geometry of the active window
        geometry=$(hyprctl activewindow | grep "at:" | cut -d' ' -f2)
        size=$(hyprctl activewindow | grep "size:" | cut -d' ' -f2 | sed 's/,/x/')
        window_geo="${geometry} ${size}"
        
        notify "Starting active window recording..."
        wf-recorder -g "$window_geo" -f "$output_file" &> /dev/null &
        ;;
    "󰩬 Select Region")
        # Select a region using slurp
        geometry=$(slurp)
        
        # Exit if slurp was cancelled
        if [ -z "$geometry" ]; then
            notify "Recording cancelled."
            exit 0
        fi
        
        notify "Starting selected region recording..."
        wf-recorder -g "$geometry" -f "$output_file" &> /dev/null &
        ;;
esac