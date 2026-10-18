#!/usr/bin/env bash
# ExecStop for tmux.service: resurrect's save.sh, run with no server, writes an empty save
# and repoints `last` at it, destroying the last good snapshot.
set -u

: "${TMUX_BIN:=}"
[ -n "$TMUX_BIN" ] || TMUX_BIN="$(command -v tmux || true)"
[ -n "$TMUX_BIN" ] || TMUX_BIN=/run/current-system/sw/bin/tmux
[ -x "$TMUX_BIN" ] || exit 0

# No server, or a server with no sessions -> nothing worth saving. Bail out
# *without* touching the resurrect directory.
"$TMUX_BIN" has-session 2>/dev/null || exit 0

exec "$HOME/.config/tmux/plugins/tmux-resurrect/scripts/save.sh"
