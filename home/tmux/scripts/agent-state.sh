#!/usr/bin/env bash
# Agent state awareness for tmux -- "which of my agents is blocked on me?"
#
# This is the tmux-native answer to Herdr. Herdr is a *replacement* multiplexer,
# so adopting it would mean giving up tmux-resurrect, tmux-continuum, the
# systemd unit in home/modules/extras.nix, tmuxifier and vim-tmux-navigator.
# Not worth it for a status chip.
#
# The usual objection to building this on tmux is that you must scrape panes
# with capture-pane and regex for "Do you want to proceed?". That is out of
# date. Claude Code, Codex, opencode and antigravity all emit lifecycle hooks,
# so the agent REPORTS its state and we never guess. That is why this is a few
# hundred lines of shell instead of a brittle screen-scraper.
#
# State lives in the @agent-state PANE option. Deliberate: no cache files, no
# orphan pruning, no XDG_RUNTIME_DIR cleanup, because tmux drops the option when
# the pane dies. tmux-resurrect does not restore pane options, which is also
# correct -- a restored pane has no agent running in it.
#
# Live-editable: home/tmux is an out-of-store symlink (home/modules/extras.nix),
# so edits here take effect on the next redraw with no rebuild.

# NOTE: no `set -e`. This runs from status-right; a nonzero exit would blank the
# segment on any transient tmux hiccup. Failures degrade to an empty chip.
set -uo pipefail

readonly STATE_OPT='@agent-state'
readonly STAMP_OPT='@agent-state-at'
# Second channel, same footer: a shell command that finished in a window I was
# not looking at. Kept separate from @agent-state so an agent chip and a command
# chip can coexist on the same pane.
readonly RUN_OPT='@run-state'       # ok | fail
readonly RUN_INFO_OPT='@run-info'   # preformatted "w2 nix 42s"
readonly RUN_AT_OPT='@run-at'       # epoch, so the renderer can rank by recency
readonly RUN_MAX=2                  # chips rendered; footer is only 160 wide

# Severity order. `status` folds a session's panes down to its worst state, and
# `pick` sorts by this so whatever is blocking me lands at the top.
rank() {
  case $1 in
    blocked) echo 3 ;;
    working) echo 2 ;;
    done)    echo 1 ;;
    *)       echo 0 ;;
  esac
}

glyph() {
  case $1 in
    blocked) echo '●' ;;
    working) echo '◐' ;;
    done)    echo '✓' ;;
    *)       echo '·' ;;
  esac
}

# Catppuccin mocha. Read the live @thm_* options first so a flavour change in
# tmux.conf carries over; fall back to mocha hexes when catppuccin has not
# loaded yet (TPM runs after the first status draw on a cold start).
colour() {
  local name fallback val
  case $1 in
    blocked) name='@thm_red';    fallback='#f38ba8' ;;
    working) name='@thm_peach';  fallback='#fab387' ;;
    done)    name='@thm_green';  fallback='#a6e3a1' ;;
    *)       name='@thm_overlay_1'; fallback='#7f849c' ;;
  esac
  val=$(tmux show -gqv "$name" 2>/dev/null)
  [ -n "$val" ] && echo "$val" || echo "$fallback"
}

# tmux re-expands the output of #(), so a '#' in a session name would be parsed
# as the start of a format. Double it.
esc() { printf '%s' "${1//#/##}"; }

die_unless_pane() {
  [ -n "${TMUX_PANE:-}" ] || exit 0
  command -v tmux >/dev/null 2>&1 || exit 0
}

# Pull the client to whatever just blocked, the way Herdr jumps you to the pane
# that needs an answer. Opt-out with `set -g @agent-autofocus off` in tmux.conf.
#
# Guarded three ways, because stealing focus mid-keystroke is worse than a
# missed chip: only on `blocked`, only when that pane is not already the one you
# are looking at, and never when a popup/copy-mode/prefix is active -- switching
# out from under those eats the keystroke.
autofocus() {
  local pane=$1 sess win
  [ "$(tmux show -gqv '@agent-autofocus')" = "off" ] && return 0

  # Both guards below come from `list-clients`, NOT `display -p`. Two traps:
  # `display -p` with no target resolves the pane from $TMUX_PANE, which a hook
  # sets to the pane that just blocked -- so it always claims we are already
  # looking at it. And `display -p -c <client>` does not fix that: -c only
  # scopes #{client_*} formats, the pane target still comes from the env.
  # list-clients reports each client's genuinely active pane.
  local focused
  focused=$(tmux list-clients -F '#{pane_id}' 2>/dev/null | head -1)
  [ -n "$focused" ] || return 0            # nobody attached, nothing to focus

  # Already looking at it?
  [ "$focused" = "$pane" ] && return 0

  # Mid-interaction: prefix held, or in copy-mode. Switching out from under
  # either eats the keystroke.
  case $(tmux list-clients -F '#{client_prefix}#{pane_in_mode}' 2>/dev/null | head -1) in
    *1*) return 0 ;;
  esac

  sess=$(tmux display -p -t "$pane" '#{session_name}' 2>/dev/null) || return 0
  [ -n "$sess" ] || return 0
  win=$(tmux display -p -t "$pane" '#{window_id}' 2>/dev/null)

  # Move every attached client, not just the "current" one -- a hook runs with
  # no client of its own, so tmux would otherwise guess.
  local c
  for c in $(tmux list-clients -F '#{client_name}' 2>/dev/null); do
    tmux switch-client -c "$c" -t "$sess" 2>/dev/null
  done
  tmux select-window -t "$win"  2>/dev/null
  tmux select-pane   -t "$pane" 2>/dev/null
}

cmd_set() {
  local state=${1:-idle}
  die_unless_pane
  tmux set -p -t "$TMUX_PANE" "$STATE_OPT" "$state" 2>/dev/null || exit 0
  tmux set -p -t "$TMUX_PANE" "$STAMP_OPT" "$(date +%s)" 2>/dev/null
  # Push the redraw instead of waiting for status-interval. This is what keeps
  # the bar instant without polling every pane on a timer.
  tmux refresh-client -S 2>/dev/null

  [ "$state" = blocked ] && autofocus "$TMUX_PANE"
  return 0
}

cmd_clear() {
  die_unless_pane
  tmux set -p -u -t "$TMUX_PANE" "$STATE_OPT" 2>/dev/null
  tmux set -p -u -t "$TMUX_PANE" "$STAMP_OPT" 2>/dev/null
  tmux refresh-client -S 2>/dev/null
}

# Bound to the after-select-window hook: a 'done' chip is sticky so I still see
# that a session finished while I was elsewhere, and looking at the window is
# what acknowledges it. 'blocked' and 'working' are left alone -- those are live
# facts about the agent, not notifications.
cmd_clear_done() {
  # No argument means "the window this hook fired for" -- run-shell inherits the
  # hook's target, and list-panes with no -t defaults to the current window.
  local target=${1:-}
  local -a tflag=()
  [ -n "$target" ] && tflag=(-t "$target")
  local pane
  while read -r pane; do
    [ -n "$pane" ] || continue
    tmux set -p -u -t "$pane" "$STATE_OPT" 2>/dev/null
    tmux set -p -u -t "$pane" "$STAMP_OPT" 2>/dev/null
  done < <(tmux list-panes "${tflag[@]}" -F "#{pane_id} #{$STATE_OPT}" 2>/dev/null \
             | awk '$2 == "done" { print $1 }')

  # Command chips acknowledge the same way: looking at the window is the ack.
  # Unlike agent state there is no "live" variant to preserve -- a finished
  # command is always just a notification.
  while read -r pane; do
    [ -n "$pane" ] || continue
    tmux set -p -u -t "$pane" "$RUN_OPT" 2>/dev/null
    tmux set -p -u -t "$pane" "$RUN_INFO_OPT" 2>/dev/null
    tmux set -p -u -t "$pane" "$RUN_AT_OPT" 2>/dev/null
  done < <(tmux list-panes "${tflag[@]}" -F "#{pane_id} #{$RUN_OPT}" 2>/dev/null \
             | awk '$2 != "" { print $1 }')

  tmux refresh-client -S 2>/dev/null
}

# Fold every pane on the server down to one worst-state row per session, then
# render chips. Sessions with no agent emit nothing, so the bar stays empty
# until something is actually running.
cmd_status() {
  local current=${1:-}
  local out='' sess state colr gl style

  while IFS=$'\t' read -r sess state _; do
    [ -n "$sess" ] || continue
    colr=$(colour "$state")
    gl=$(glyph "$state")
    # The current session already has a catppuccin segment of its own, so dim
    # its chip -- the point of this bar is the sessions I am NOT looking at.
    if [ "$sess" = "$current" ]; then
      style="#[fg=$colr,dim]"
    else
      style="#[fg=$colr,bold]"
    fi
    out+="${style}${gl} $(esc "$sess")#[default]  "
  done < <(
    tmux list-panes -a -F "#{session_name}"$'\t'"#{$STATE_OPT}" 2>/dev/null \
      | awk -F'\t' '
          BEGIN { r["blocked"]=3; r["working"]=2; r["done"]=1 }
          $2 == "" { next }
          !($2 in r) { next }
          r[$2] > best[$1] { best[$1] = r[$2]; st[$1] = $2 }
          END { for (s in st) printf "%s\t%s\t%d\n", s, st[s], best[s] }
        ' \
      | sort -t$'\t' -k3,3nr -k1,1
  )

  # Command chips, newest first, capped at RUN_MAX.
  local rstate rinfo
  while IFS=$'\t' read -r rstate rinfo; do
    [ -n "$rinfo" ] || continue
    if [ "$rstate" = fail ]; then
      out+="#[fg=$(colour blocked),bold]✗ $(esc "$rinfo")#[default]  "
    else
      out+="#[fg=$(colour 'done'),bold]✓ $(esc "$rinfo")#[default]  "
    fi
  done < <(
    tmux list-panes -a -F "#{$RUN_OPT}"$'\t'"#{$RUN_INFO_OPT}"$'\t'"#{$RUN_AT_OPT}" 2>/dev/null \
      | awk -F'\t' '$1 != "" && $2 != "" { printf "%d\t%s\t%s\t%s\n", ($1=="fail"?1:0), $3, $1, $2 }' \
      | sort -t$'\t' -k1,1nr -k2,2nr \
      | cut -f3- \
      | head -n "$RUN_MAX"
  )

  printf '%s' "$out"
}

# A shell command finished. Called from the zsh precmd hook in
# home/zsh/scripts/cmd-notify.sh, which has ALREADY applied the duration
# threshold -- by the time we are exec'd the command is known to be worth
# reporting, so nothing here second-guesses that.
#
#   run-done <exit-code> <seconds> <command...>
cmd_run_done() {
  local code=${1:-0} secs=${2:-0}; shift 2 || true
  local cmdline="$*"
  die_unless_pane

  # "Am I in a different tab?" -- the whole point of the feature. Compare the
  # CLIENT's window, via list-clients. Not `display -p`: that resolves the
  # target from $TMUX_PANE, which this hook sets to the finishing pane, so it
  # would always say we are already there. (Same trap as autofocus above.)
  local here there
  here=$(tmux list-clients -F '#{window_id}' 2>/dev/null | head -1)
  there=$(tmux display -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null)
  [ -n "$here" ] && [ "$here" = "$there" ] && return 0

  # Label the window the way I would have to navigate to it. A bare window
  # index is ambiguous the moment more than one session is open -- Claude:0 and
  # main:0 are both "0" -- so qualify with the session name whenever the pane
  # is not in the session I am currently viewing.
  local win label state mysess itssess
  win=$(tmux display -p -t "$TMUX_PANE" '#{window_index}' 2>/dev/null)
  mysess=$(tmux list-clients -F '#{client_session}' 2>/dev/null | head -1)
  itssess=$(tmux display -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null)
  if [ -n "$itssess" ] && [ "$itssess" != "$mysess" ]; then
    win="${itssess}:${win}"          # another session: name it
  else
    win="w${win}"                    # this session: just the tab number
  fi
  # First word only, basename'd, clipped -- "nix build .#foo --bar" -> "nix".
  label=${cmdline%% *}
  label=${label##*/}
  [ ${#label} -gt 12 ] && label=${label:0:12}

  if [ "$code" -eq 0 ]; then state=ok; else state=fail; fi

  tmux set -p -t "$TMUX_PANE" "$RUN_OPT" "$state" 2>/dev/null || return 0
  tmux set -p -t "$TMUX_PANE" "$RUN_INFO_OPT" "${win} ${label} ${secs}s" 2>/dev/null
  tmux set -p -t "$TMUX_PANE" "$RUN_AT_OPT" "$(date +%s)" 2>/dev/null
  tmux refresh-client -S 2>/dev/null

  # Toast on failure only -- success stays in the footer so this does not
  # compete with the Claude Code notifications. Same synchronous-hint pattern
  # as home/claude/hooks/claude-notify.sh so repeats replace rather than stack.
  if [ "$state" = fail ] && command -v notify-send >/dev/null 2>&1; then
    notify-send -a "tmux" -u normal -i utilities-terminal \
      -h "string:x-canonical-private-synchronous:run-${TMUX_PANE}" \
      "Command failed  (exit $code)" \
      "$cmdline
window $win  •  after ${secs}s"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Hook adapters. Each agent hands us its lifecycle event as JSON on stdin; we
# map it to a state and write it. These always exit 0 -- a hook that fails must
# never be able to wedge the agent it is attached to.
# ---------------------------------------------------------------------------

# Claude Code. Registered from home/claude/settings.json. Notification and Stop
# are driven from claude-notify.sh instead, which was already parsing these
# events to build desktop notifications -- no point spawning a second jq for
# them. They stay handled here too so this adapter works standalone.
cmd_claude() {
  local event
  event=$(jq -r '.hook_event_name // ""' 2>/dev/null)
  case $event in
    SessionStart)     cmd_set idle ;;
    UserPromptSubmit) cmd_set working ;;
    Notification)     cmd_set blocked ;;
    Stop)             cmd_set 'done' ;;
    SessionEnd)       cmd_clear ;;
  esac
  exit 0
}

# Codex CLI and antigravity (agy). Both ship a hooks.json whose event names I
# could only confirm by reading the shipped binary, and codex carries BOTH a
# PascalCase set (PreToolUse, SessionStart, ...) and a kebab-case set
# (pre-tool-use, session-start, ...) -- it can import Claude Code hook configs,
# which is presumably why. Rather than bet on one, normalise: lowercase and
# strip separators, then match. Same for the field the event name arrives in.
cmd_hook() {
  local raw event
  raw=$(jq -r '.hook_event_name // .event // .type // .eventName // ""' 2>/dev/null)
  event=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '_-')
  case $event in
    sessionstart)             cmd_set idle ;;
    userpromptsubmit)         cmd_set working ;;
    pretooluse)               cmd_set working ;;
    permissionrequest)        cmd_set blocked ;;
    stop)                     cmd_set 'done' ;;
    sessionend)               cmd_clear ;;
  esac
  exit 0
}

# Jump to whatever is blocking me. Bound to prefix+a. Only lists panes that
# actually have an agent in them -- the whole point is to skip the ones that do
# not need me. Blocked sorts to the top.
cmd_pick() {
  local rows sel pane sess
  rows=$(
    tmux list-panes -a -F "#{$STATE_OPT}"$'\t'"#{pane_id}"$'\t'"#{session_name}:#{window_index}.#{pane_index}"$'\t'"#{pane_current_command}"$'\t'"#{$STAMP_OPT}" 2>/dev/null \
      | awk -F'\t' -v now="$(date +%s)" '
          BEGIN { r["blocked"]=3; r["working"]=2; r["done"]=1
                  g["blocked"]="\xe2\x97\x8f"; g["working"]="\xe2\x97\x90"; g["done"]="\xe2\x9c\x93" }
          $1 == "" || !($1 in r) { next }
          {
            age = ($5 == "" ? 0 : now - $5)
            if (age >= 3600)    ago = sprintf("%dh", age/3600)
            else if (age >= 60) ago = sprintf("%dm", age/60)
            else                ago = sprintf("%ds", age)
            printf "%d\t%s\t%s %-28s %-12s %s\n", r[$1], $2, g[$1], $3, $4, ago
          }
        ' \
      | sort -t$'\t' -k1,1nr
  )

  if [ -z "$rows" ]; then
    echo "No agents running." >&2
    read -r -n1 -p "Press any key..." _ || true
    return 0
  fi

  # Field 1 is the sort rank and field 2 the pane id; show only field 3 onward.
  sel=$(printf '%s\n' "$rows" \
    | fzf --ansi --no-sort --delimiter=$'\t' --with-nth=3.. \
          --height=100% --reverse --prompt='agent> ' 2>/dev/null) || return 0
  [ -n "$sel" ] || return 0

  pane=$(printf '%s' "$sel" | cut -f2)
  [ -n "$pane" ] || return 0
  sess=$(tmux display -p -t "$pane" '#{session_name}' 2>/dev/null)
  [ -n "$sess" ] && tmux switch-client -t "$sess" 2>/dev/null
  tmux select-window -t "$pane" 2>/dev/null
  tmux select-pane   -t "$pane" 2>/dev/null
}

# antigravity (agy). Three things make it unlike the others, all confirmed from
# the documentation embedded in the agy binary itself:
#
#  1. The stdin payload carries NO event name -- only conversationId,
#     workspacePaths, transcriptPath, modelName and per-event extras. So the
#     event is passed as an argument from hooks.json instead of parsed.
#  2. Every hook MUST print a JSON object on stdout. Stop additionally requires
#     a `decision` field, where "continue" would BLOCK the agent from stopping.
#     We must emit something else -- hence {"decision":"stop"}.
#  3. "Hooks run synchronously and block the agent loop." Keep this fast; it is
#     two tmux calls and no jq.
#
# agy has no approval/permission event in its five, so it can never report
# `blocked`. working/done/idle only. That is a limitation of agy, not of this
# script -- see home/agy/hooks.json.
cmd_agy() {
  case ${1:-} in
    PreInvocation|PostInvocation) cmd_set working; printf '{}' ;;
    Stop)                         cmd_set 'done';    printf '{"decision":"stop"}' ;;
    *)                            printf '{}' ;;
  esac
  exit 0
}

case "${1:-}" in
  set)        shift; cmd_set "$@" ;;
  clear)      shift; cmd_clear "$@" ;;
  clear-done) shift; cmd_clear_done "$@" ;;
  status)     shift; cmd_status "$@" ;;
  claude)     shift; cmd_claude "$@" ;;
  codex)      shift; cmd_hook "$@" ;;
  agy)        shift; cmd_agy "$@" ;;
  pick)       shift; cmd_pick "$@" ;;
  run-done)   shift; cmd_run_done "$@" ;;
  *)
    echo "usage: agent-state.sh {set <state>|clear|clear-done <win>|status [sess]|pick|claude|codex|agy|run-done <code> <secs> <cmd>}" >&2
    echo "       states: blocked working done idle" >&2
    exit 2
    ;;
esac
