#!/usr/bin/env bash
# ExecStop for tmux.service (see home/modules/extras.nix).
#
# tmux-resurrect's save.sh never checks whether a tmux server is actually
# running. When it isn't, every `tmux list-*` inside it fails, save.sh still
# creates a save file (zero bytes), and still repoints
# ~/.local/share/tmux/resurrect/last at that empty file -- silently destroying
# the last good snapshot. That is what wiped session state on every boot.
set -u

: "${TMUX_BIN:=}"
[ -n "$TMUX_BIN" ] || TMUX_BIN="$(command -v tmux || true)"
[ -n "$TMUX_BIN" ] || TMUX_BIN=/run/current-system/sw/bin/tmux
[ -x "$TMUX_BIN" ] || exit 0

# No server, or a server with no sessions -> nothing worth saving. Bail out
# *without* touching the resurrect directory.
"$TMUX_BIN" has-session 2>/dev/null || exit 0

exec "$HOME/.config/tmux/plugins/tmux-resurrect/scripts/save.sh"
