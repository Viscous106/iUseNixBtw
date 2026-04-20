#!/bin/bash

CACHE_FILE="${HOME}/.cache/last_closed_app"

if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
    COMMAND=$(cat "$CACHE_FILE")
    echo "Relaunching: $COMMAND"
    # Execute the command in the background
    eval "$COMMAND" &
else
    echo "No last closed app command found in $CACHE_FILE"
fi
