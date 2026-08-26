# Interactive branch switch with fzf (works in bare repos too) 
fzb() {
  # Use for-each-ref which works in bare repos
  local branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null |
    grep -v '/HEAD$' |
    fzf --height 40% --reverse --tac --prompt="Branch > ") 
  if [[ -n "$branch" ]]; then
    # If in a bare repo, suggest using gws instead
    if [[ "$(git rev-parse --is-bare-repository 2>/dev/null)" == "true" ]]; then
      echo "Bare repo detected. Use 'gws' to switch worktrees."
      echo "Selected branch: $branch"
    else
      git checkout "$branch"
    fi
  fi
}

# Worktree switcher - cd to selected worktree
gws() {
  local target=$("$HOME/.config/hypr/scripts/worktree_switcher.sh" --print-only 2>/dev/null)
  [[ -n "$target" && -d "$target" ]] && cd "$target" && echo "Switched to: $(basename "$target")"
}

# Worktree switcher - open in nvim
gwn() {
  "$HOME/.config/hypr/scripts/worktree_switcher.sh" --nvim
}

# Quick branch creation
gnb() {
  [[ -z "$1" ]] && echo "Usage: gnb <branch-name>" && return 1
  git checkout -b "$1"
}
# --- End Git & Worktree Management ---
