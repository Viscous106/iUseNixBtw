#!/usr/bin/env bash
# Desktop notification bridge for Claude Code (notify-send -> swaync).
# Wired from ~/.config/claude/settings.json (CLAUDE_CONFIG_DIR on this
# machine); the hook JSON arrives on stdin.

input=$(cat)
event=$(jq -r '.hook_event_name // "Notification"' <<<"$input" 2>/dev/null)
msg=$(jq -r '.message // ""'                       <<<"$input" 2>/dev/null)
cwd=$(jq -r '.cwd // ""'                           <<<"$input" 2>/dev/null)

where=${cwd##*/}
if [ -n "$TMUX_PANE" ] && command -v tmux >/dev/null 2>&1; then
  pane=$(tmux display-message -p -t "$TMUX_PANE" '#S:#I' 2>/dev/null)
  [ -n "$pane" ] && where="$where  •  $pane"
fi

case $event in
  Notification)
    state=blocked
    urgency=critical
    title="Claude needs you"
    body=${msg:-Waiting for your input}
    sound=/run/current-system/sw/share/sounds/freedesktop/stereo/message.oga
    ;;
  Stop)
    state=done
    urgency=normal
    title="Claude finished"
    body="Turn complete — ready for the next instruction"
    sound=/run/current-system/sw/share/sounds/freedesktop/stereo/complete.oga
    ;;
  *)
    state=
    urgency=normal
    title="Claude Code"
    body=${msg:-$event}
    sound=
    ;;
esac

# Feed the tmux status bar the same event we are about to toast. This script
# already resolves $TMUX_PANE for the notification body, so the pane is known;
# agent-state.sh turns it into a chip in status-right. See
# home/tmux/scripts/agent-state.sh. Best-effort -- never block the notification.
agent_state=$HOME/.config/tmux/scripts/agent-state.sh
if [ -n "$state" ] && [ -x "$agent_state" ]; then
  "$agent_state" set "$state" || true
fi

notify-send -a "Claude Code" -u "$urgency" -i utilities-terminal \
  -h "string:x-canonical-private-synchronous:claude-${TMUX_PANE:-0}" \
  "$title" "$body
$where"

[ -n "$sound" ] && [ -r "$sound" ] && paplay "$sound" >/dev/null 2>&1 &
exit 0
