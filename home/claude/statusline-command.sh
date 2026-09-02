#!/usr/bin/env bash
# Claude Code statusLine — converted from the Starship prompt at
# ~/.config/zsh/starship.toml (itself migrated from powerlevel10k; palette
# name "p10k" is preserved there for that reason).
#
# Layout mirrors the starship `format`:
#   LEFT:  os -> directory -> git_branch -> git_status -> fade
#   RIGHT: model -> context% -> rate-limits -> vim-mode -> output-style ->
#          pr -> time
# using the same [palettes.p10k] ANSI-256 colors and the same
# "░▒▓ … ▓▒░" powerline fade-glyph style as the original config.
#
# Git commands use --no-optional-locks so the statusline never blocks a
# concurrent git operation.

input=$(cat)

# ---------------------------------------------------------------------------
# color helpers (ANSI-256, matches [palettes.p10k] in starship.toml)
# ---------------------------------------------------------------------------
RESET=$'\033[0m'
fg() { printf '\033[38;5;%sm' "$1"; }
bg() { printf '\033[48;5;%sm' "$1"; }

# palette
OS_BG=254;  OS_FG=232
DIR_BG=4;   DIR_FG=254   # named "blue"
GIT_BG=2;   GIT_FG=232   # named "green"

# fade-in glyph: colored as the *upcoming* segment's background, no bg of its
# own (mirrors starship's `[░▒▓](fg:N)` transparent lead-in used by
# status/cmd_duration/jobs/etc.)
fade_in() { printf '%s░▒▓%s' "$(fg "$1")" "$RESET"; }
# fade-out glyph: colored as the *closing* segment's background (mirrors
# starship's `[▓▒░](fg:N)` git_end/dir_end)
fade_out() { printf '%s▓▒░%s' "$(fg "$1")" "$RESET"; }

# ---------------------------------------------------------------------------
# gather data
# ---------------------------------------------------------------------------
cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir')
model=$(printf '%s' "$input" | jq -r '.model.display_name')
style=$(printf '%s' "$input" | jq -r '.output_style.name // "default"')
used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
five=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
vim_mode=$(printf '%s' "$input" | jq -r '.vim.mode // empty')
pr_num=$(printf '%s' "$input" | jq -r '.pr.number // empty')
pr_state=$(printf '%s' "$input" | jq -r '.pr.review_state // empty')
worktree=$(printf '%s' "$input" | jq -r '.worktree.name // empty')
agent=$(printf '%s' "$input" | jq -r '.agent.name // empty')

cd "$cwd" 2>/dev/null || true

# ---------------------------------------------------------------------------
# LEFT: os
# ---------------------------------------------------------------------------
out=""
out+="$(fg $OS_FG)$(bg $OS_BG) $(printf '')  $RESET"   # os symbol (Arch)
out+="$(fg $OS_BG)$(bg $DIR_BG)$(printf '')$RESET"       # -> directory

# ---------------------------------------------------------------------------
# LEFT: directory (home_symbol=' ~', truncation_length=3, truncate_to_repo)
# ---------------------------------------------------------------------------
dir_display="$cwd"
if [ "$cwd" = "$HOME" ]; then
  dir_display=" ~"
else
  case "$cwd" in
    "$HOME"/*) dir_display="~/${cwd#"$HOME"/}" ;;
  esac
  IFS='/' read -r -a _parts <<< "$dir_display"
  _n=${#_parts[@]}
  if [ "$_n" -gt 3 ]; then
    _tail=("${_parts[@]: -3}")
    _joined=$(IFS=/; printf '%s' "${_tail[*]}")
    dir_display="…/${_joined}"
  fi
fi
out+="$(fg $DIR_FG)$(bg $DIR_BG) ${dir_display} $RESET"

# ---------------------------------------------------------------------------
# LEFT: git branch + status (skips optional locks)
# ---------------------------------------------------------------------------
in_git=$(git --no-optional-locks -C "$cwd" rev-parse --is-inside-work-tree 2>/dev/null)
if [ "$in_git" = "true" ]; then
  out+="$(fg $DIR_BG)$(bg $GIT_BG)$(printf '')$RESET"    # -> git

  branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  out+="$(fg $GIT_FG)$(bg $GIT_BG)  ${branch} $RESET"

  status_out=$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null)
  staged=$(printf '%s\n' "$status_out" | grep -c '^[MADRC]')
  modified=$(printf '%s\n' "$status_out" | grep -c '^.M')
  deleted=$(printf '%s\n' "$status_out" | grep -c '^.D')
  untracked=$(printf '%s\n' "$status_out" | grep -c '^??')
  stashed=$(git --no-optional-locks -C "$cwd" stash list 2>/dev/null | wc -l)
  upstream=$(git --no-optional-locks -C "$cwd" rev-parse --abbrev-ref '@{u}' 2>/dev/null)
  ahead=0; behind=0
  if [ -n "$upstream" ]; then
    read -r behind ahead < <(git --no-optional-locks -C "$cwd" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
  fi

  status_str=""
  [ "$staged" -gt 0 ] 2>/dev/null && status_str+="+${staged} "
  [ "$modified" -gt 0 ] 2>/dev/null && status_str+="!${modified} "
  [ "$deleted" -gt 0 ] 2>/dev/null && status_str+="✘${deleted} "
  [ "$untracked" -gt 0 ] 2>/dev/null && status_str+="?${untracked} "
  [ "$stashed" -gt 0 ] 2>/dev/null && status_str+="*${stashed} "
  if [ -n "$upstream" ]; then
    if [ "${ahead:-0}" -gt 0 ] && [ "${behind:-0}" -gt 0 ]; then
      status_str+="⇕⇡${ahead}⇣${behind} "
    elif [ "${ahead:-0}" -gt 0 ]; then
      status_str+="⇡${ahead} "
    elif [ "${behind:-0}" -gt 0 ]; then
      status_str+="⇣${behind} "
    fi
  fi
  if [ -n "$status_str" ]; then
    out+="$(fg $GIT_FG)$(bg $GIT_BG)${status_str}$RESET"
  fi

  out+="$(fade_out $GIT_BG)"   # green end-fade — matches custom.git_end
else
  out+="$(fade_out $DIR_BG)"   # blue end-fade — matches custom.dir_end
fi

# ---------------------------------------------------------------------------
# separator (stand-in for starship's dynamic-width $fill, style fg:240)
# ---------------------------------------------------------------------------
out+="  $(fg 240)···$RESET  "

# ---------------------------------------------------------------------------
# RIGHT: model (stands in for the language-version modules, e.g. $python)
# ---------------------------------------------------------------------------
out+="$(fade_in 4)$(fg 0)$(bg 4)  ${model} $RESET"

# ---------------------------------------------------------------------------
# RIGHT: context window usage — green/yellow/red like git_status severity
# ---------------------------------------------------------------------------
if [ -n "$used" ]; then
  ctx_bg=2
  awk_cmp=$(awk -v u="$used" 'BEGIN{ if (u>=90) print "red"; else if (u>=70) print "yellow"; else print "green" }')
  case "$awk_cmp" in
    red) ctx_bg=1 ;;
    yellow) ctx_bg=3 ;;
    *) ctx_bg=2 ;;
  esac
  used_r=$(awk -v u="$used" 'BEGIN{printf "%.0f", u}')
  out+="$(fade_in $ctx_bg)$(fg 0)$(bg $ctx_bg)  ctx ${used_r}% $RESET"
fi

# ---------------------------------------------------------------------------
# RIGHT: Claude subscription rate limits (5h / 7d), like $cmd_duration
# ---------------------------------------------------------------------------
if [ -n "$five" ] || [ -n "$week" ]; then
  rl=""
  [ -n "$five" ] && rl+="5h:$(awk -v v="$five" 'BEGIN{printf "%.0f", v}')% "
  [ -n "$week" ] && rl+="7d:$(awk -v v="$week" 'BEGIN{printf "%.0f", v}')% "
  out+="$(fade_in 3)$(fg 0)$(bg 3) ${rl}$RESET"
fi

# ---------------------------------------------------------------------------
# RIGHT: vim mode, like a $character indicator (insert=green, normal=blue,
# visual=magenta)
# ---------------------------------------------------------------------------
if [ -n "$vim_mode" ]; then
  case "$vim_mode" in
    INSERT) vbg=2 ;;
    NORMAL) vbg=4 ;;
    *) vbg=5 ;;
  esac
  out+="$(fade_in $vbg)$(fg 0)$(bg $vbg) -- ${vim_mode} -- $RESET"
fi

# ---------------------------------------------------------------------------
# RIGHT: output style (only when not "default")
# ---------------------------------------------------------------------------
if [ -n "$style" ] && [ "$style" != "default" ]; then
  out+="$(fade_in 6)$(fg 0)$(bg 6)  ${style} $RESET"
fi

# ---------------------------------------------------------------------------
# RIGHT: worktree / agent (extra context this session carries)
# ---------------------------------------------------------------------------
if [ -n "$worktree" ]; then
  out+="$(fade_in 5)$(fg 0)$(bg 5)  ${worktree} $RESET"
fi
if [ -n "$agent" ]; then
  out+="$(fade_in 6)$(fg 0)$(bg 6)  ${agent} $RESET"
fi

# ---------------------------------------------------------------------------
# RIGHT: PR badge, like a $kubernetes "at" segment
# ---------------------------------------------------------------------------
if [ -n "$pr_num" ]; then
  out+="$(fade_in 5)$(fg 0)$(bg 5)  PR #${pr_num}${pr_state:+ (${pr_state})} $RESET"
fi

# ---------------------------------------------------------------------------
# RIGHT: time, time_format '%I:%M:%S %p'
# ---------------------------------------------------------------------------
out+="$(fade_in 7)$(fg 0)$(bg 7)  at $(date '+%I:%M:%S %p')  $RESET"

printf '%s' "$out"
