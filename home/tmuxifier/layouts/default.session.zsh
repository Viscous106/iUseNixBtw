# ~/.config/tmuxifier/layouts/default.session.zsh

# Set the session name
session_name "default"

# Set the root directory for the session
root_dir "$HOME"

# Create the first window
new_window "main"

# Split the window vertically
split_v 25

# Select the first pane (the larger one)
select_pane 0

# You could automatically start nvim here if you wanted:
# send_keys "nvim" C-m

# Select the second pane
select_pane 1

# Create a second window for servers/processes
new_window "servers"

# Go back to the first window
select_window 0
