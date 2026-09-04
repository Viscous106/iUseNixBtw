#!/usr/bin/env bash
# ExecStart for tmux.service (see home/modules/extras.nix).
#
# Must be idempotent: a `home-manager switch` restarts the unit while a tmux
# server is already up. `new-session -A -d -s main` is NOT idempotent here --
# with -A on an existing session it behaves like attach-session and dies with
# "open terminal failed: not a terminal" under systemd.
set -u

: "${TMUX_BIN:=}"
[ -n "$TMUX_BIN" ] || TMUX_BIN="$(command -v tmux || true)"
[ -n "$TMUX_BIN" ] || TMUX_BIN=/run/current-system/sw/bin/tmux

# Server already has sessions (restored or hand-made) -> leave it alone.
"$TMUX_BIN" has-session 2>/dev/null && exit 0

# A server with zero sessions exits immediately, so create a real one; tmux
# sources tmux.conf here, which loads tmux-continuum and triggers
# @continuum-restore in the background.
exec "$TMUX_BIN" new-session -d -s main
