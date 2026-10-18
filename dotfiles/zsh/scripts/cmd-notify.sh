# Long-running command finished in an unseen window -> tmux footer chip (rendered by agent-state.sh).
# The threshold check is pure zsh because precmd runs after every command; no forks until it passes.

zmodload zsh/datetime 2>/dev/null   # EPOCHSECONDS
autoload -Uz add-zsh-hook

# Seconds a command must run before it is worth reporting.
: ${CMD_NOTIFY_THRESHOLD:=10}

# Interactive programs whose "runtime" is just me using them. Without this,
# quitting nvim after five minutes raises a chip.
: ${CMD_NOTIFY_IGNORE:="nvim vim vi less more man top htop btop watch ssh tmux claude codex opencode agy fzf git-commit"}

_cmd_notify_start=0
_cmd_notify_line=''

_cmd_notify_preexec() {
  _cmd_notify_start=$EPOCHSECONDS
  _cmd_notify_line=$1
}

_cmd_notify_precmd() {
  local code=$?                       # MUST be first: anything else clobbers it
  local start=$_cmd_notify_start
  local line=$_cmd_notify_line
  _cmd_notify_start=0
  _cmd_notify_line=''

  (( start )) || return               # precmd without a preexec (fresh prompt)
  [[ -n $TMUX_PANE ]] || return       # not in tmux, nothing to chip

  local elapsed=$(( EPOCHSECONDS - start ))
  (( elapsed >= CMD_NOTIFY_THRESHOLD )) || return

  # First word, minus any path and any leading VAR=val assignments.
  local -a words=( ${(z)line} )
  local head=''
  local w
  for w in $words; do
    [[ $w == *=* ]] && continue
    head=${w:t}
    break
  done
  [[ -n $head ]] || return
  [[ " $CMD_NOTIFY_IGNORE " == *" $head "* ]] && return

  "$HOME/.config/tmux/scripts/agent-state.sh" run-done "$code" "$elapsed" "$line" &!
}

add-zsh-hook preexec _cmd_notify_preexec
add-zsh-hook precmd  _cmd_notify_precmd
