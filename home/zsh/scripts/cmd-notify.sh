# Report long-running commands to the tmux footer.
#
# A command that finishes in a window I am not looking at gets a chip in
# status-right: green tick on success, red cross on failure, plus the window
# number and how long it took. Failures also raise a desktop toast. The chip
# clears when I next select that window. All of the rendering lives in
# home/tmux/scripts/agent-state.sh; this file only decides WHEN to call it.
#
# Why the threshold is enforced here and not in tmux: precmd runs after every
# single command, so the check must be pure zsh with no subprocess. Reading a
# tmux option would mean forking `tmux show` on every prompt. As written, `ls`
# and `cd` cost two integer comparisons and nothing else -- agent-state.sh is
# only exec'd once a command has actually earned a chip.
#
# Registered with add-zsh-hook, so it is additive alongside the other precmd
# consumers (starship, zoxide's chpwd, atuin). Order does not matter: zsh
# re-sets $? before calling each precmd hook, so every hook sees the real exit
# status of the command regardless of what ran before it.
#
# Live-editable: home/zsh/scripts is an out-of-store symlink, so edits here
# take effect in the next shell with no rebuild. Adding a NEW file to this
# directory does need a rebuild though -- zsh.nix sources an explicit
# allowlist, not a glob.

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
