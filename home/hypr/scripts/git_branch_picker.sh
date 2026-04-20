#!/usr/bin/env bash
# Git branch switcher for tmux popup
# Usage: git_branch_picker.sh

set -e

if ! git rev-parse --git-dir &>/dev/null; then
    echo "Not a git repository"
    exit 1
fi

# Check if bare repo
if [[ "$(git rev-parse --is-bare-repository 2>/dev/null)" == "true" ]]; then
    echo "Bare repo - use Ctrl+s g for worktree switcher"
    read -n1 -p "Press any key..."
    exit 0
fi

branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null | \
    grep -v '/HEAD$' | \
    fzf --prompt='Checkout branch > ' --height=100%)

if [[ -n "$branch" ]]; then
    # Strip remotes/origin/ prefix if present
    branch="${branch#origin/}"
    git checkout "$branch"
    echo ""
    echo "Switched to: $branch"
    sleep 1
fi
