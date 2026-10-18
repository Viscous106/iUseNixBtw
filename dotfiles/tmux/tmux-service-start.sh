#!/usr/bin/env bash
# ExecStart for tmux.service; idempotent since home-manager switch restarts it with a server up.
# Not `new-session -A`: on an existing session it acts like attach and dies under systemd.
set -u

: "${TMUX_BIN:=}"
[ -n "$TMUX_BIN" ] || TMUX_BIN="$(command -v tmux || true)"
[ -n "$TMUX_BIN" ] || TMUX_BIN=/run/current-system/sw/bin/tmux

# Server already has sessions (restored or hand-made) -> leave it alone.
"$TMUX_BIN" has-session 2>/dev/null && exit 0

# A server with no sessions exits at once; creating one sources tmux.conf, which triggers continuum-restore.
exec "$TMUX_BIN" new-session -d -s main
