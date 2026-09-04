#!/usr/bin/env bash
# Fallback session bootstrap, called from zshrc when $TMUX is unset.
# Normally tmux.service (home/modules/extras.nix) has already started the server
# and tmux-continuum has already restored; this only matters when systemd didn't
# run (e.g. bare ssh/console login).
set -u

CONTINUUM_RESTORE="$HOME/.config/tmux/plugins/tmux-continuum/scripts/continuum_restore.sh"

if tmux list-sessions >/dev/null 2>&1; then
    exit 0
fi

tmux start-server
sleep 0.5

# Trigger restoration. NOTE: the plugin tree lives under ~/.config/tmux/plugins,
# not ~/.tmux/plugins -- this path used to point at the latter, so the restore
# silently never ran and we always fell through to the empty `main` session.
if [ -x "$CONTINUUM_RESTORE" ]; then
    tmux run-shell "$CONTINUUM_RESTORE"
else
    echo "tmux-autostart: missing $CONTINUUM_RESTORE" >&2
fi

sleep 0.5

# Nothing restored -> plain default session.
if ! tmux list-sessions >/dev/null 2>&1; then
    tmux new-session -d -s main
fi
