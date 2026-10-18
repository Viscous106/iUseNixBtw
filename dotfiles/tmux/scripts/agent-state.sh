#!/usr/bin/env bash
# tmux agent-state chips, fed by the agents' lifecycle hooks (no pane scraping). State lives in the
# @agent-state pane option, so it dies with the pane and resurrect rightly doesn't restore it.

# NOTE: no `set -e`. This runs from status-right; a nonzero exit would blank the
# segment on any transient tmux hiccup. Failures degrade to an empty chip.
set -uo pipefail

readonly STATE_OPT='@agent-state'
readonly STAMP_OPT='@agent-state-at'
# Separate from @agent-state so an agent chip and a finished-command chip can coexist on one pane.
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

# Live @thm_* first so a flavour change carries over; mocha fallback before catppuccin loads (cold start).
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

# Jump to a newly blocked pane (opt out: @agent-autofocus off). Skipped if it's already active or a
# popup/copy-mode/prefix is active, since switching then eats the keystroke.
autofocus() {
  local pane=$1 sess win
  [ "$(tmux show -gqv '@agent-autofocus')" = "off" ] && return 0

  # list-clients, not `display -p`: that resolves the pane from $TMUX_PANE, which the
  # hook sets to the blocked pane (-c doesn't change that).
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

# after-select-window hook: looking at the window acks a sticky 'done' chip;
# 'blocked' and 'working' are live state, so left alone.
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

  # Command chips are always just notifications, so looking at the window clears them.
  while read -r pane; do
    [ -n "$pane" ] || continue
    tmux set -p -u -t "$pane" "$RUN_OPT" 2>/dev/null
    tmux set -p -u -t "$pane" "$RUN_INFO_OPT" 2>/dev/null
    tmux set -p -u -t "$pane" "$RUN_AT_OPT" 2>/dev/null
  done < <(tmux list-panes "${tflag[@]}" -F "#{pane_id} #{$RUN_OPT}" 2>/dev/null \
             | awk '$2 != "" { print $1 }')

  tmux refresh-client -S 2>/dev/null
}

# One worst-state chip per session; sessions with no agent emit nothing.
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

# From the zsh precmd hook (dotfiles/zsh/scripts/cmd-notify.sh), which already applied the duration threshold.
#   run-done <exit-code> <seconds> <command...>
cmd_run_done() {
  local code=${1:-0} secs=${2:-0}; shift 2 || true
  local cmdline="$*"
  die_unless_pane

  # Compare the client's window via list-clients, not `display -p` (same $TMUX_PANE trap as autofocus).
  local here there
  here=$(tmux list-clients -F '#{window_id}' 2>/dev/null | head -1)
  there=$(tmux display -p -t "$TMUX_PANE" '#{window_id}' 2>/dev/null)
  [ -n "$here" ] && [ "$here" = "$there" ] && return 0

  # Qualify with the session name when it isn't the one I'm viewing (Claude:0 vs main:0).
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

  # Toast on failure only, so it doesn't compete with Claude notifications; the sync hint
  # (as in claude-notify.sh) makes repeats replace rather than stack.
  if [ "$state" = fail ] && command -v notify-send >/dev/null 2>&1; then
    notify-send -a "tmux" -u normal -i utilities-terminal \
      -h "string:x-canonical-private-synchronous:run-${TMUX_PANE}" \
      "Command failed  (exit $code)" \
      "$cmdline
window $win  •  after ${secs}s"
  fi
  return 0
}

# Hook adapters: each maps an agent's lifecycle JSON (stdin) to a state.
# Always exit 0: a failing hook must never wedge its agent.

# Claude Code (dotfiles/claude/settings.json). claude-notify.sh drives Notification/Stop to
# reuse its jq; they're handled here too so this works standalone.
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

# Codex CLI and antigravity: event names come in PascalCase or kebab-case, so normalise
# (lowercase, strip separators) before matching; same for the field name.
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

# prefix+a: jump to a pane with an agent in it, blocked first.
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

# antigravity (agy): event comes as an argument (not in the payload); every hook must print JSON, and
# Stop's decision must not be "continue" (that blocks stopping). Hooks are synchronous: stay fast.
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
