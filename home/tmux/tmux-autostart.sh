#!/bin/bash

# Start tmux server if not running
if ! tmux list-sessions >/dev/null 2>&1; then
    tmux start-server
    
    # Wait a moment for server to start
    sleep 0.5
    
    # Trigger restoration
    tmux run-shell "/home/viscous/.tmux/plugins/tmux-continuum/scripts/continuum_restore.sh"
    
    # If no sessions were restored, create a default one
    sleep 0.5
    if ! tmux list-sessions >/dev/null 2>&1; then
        tmux new-session -d -s main
    fi
fi