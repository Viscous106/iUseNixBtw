#!/usr/bin/env bash
# Git worktree switcher for tmux - switches to worktree in SAME pane
# Usage: tmux_worktree.sh

set -e

# Find git dir (works from anywhere in worktree or bare repo)
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
if [[ -z "$GIT_DIR" ]]; then
    echo "Not a git repository"
    exit 1
fi

# List worktrees
list_worktrees() {
    git worktree list --porcelain | awk '
        /^worktree/ {wp=$2}
        /^branch/ {
            split(wp, parts, "/");
            folder=parts[length(parts)];
            if (folder != ".bare" && folder != ".git") {
                print folder " [" substr($2, 12) "] | " wp
            }
        }'
}

worktrees=$(list_worktrees)
if [[ -z "$worktrees" ]]; then
    echo "No worktrees found"
    exit 1
fi

selected=$(echo "$worktrees" | fzf \
    --prompt="Switch to worktree > " \
    --height=100% \
    --layout=reverse \
    --delimiter=' \| ' \
    --with-nth=1 \
    --preview="eza --tree --level=1 --color=always --icons \$(echo {} | awk -F' \\\\| ' '{print \$2}')" \
    --preview-window=right:50%:wrap \
    --header="ENTER: Switch | ESC: Cancel")

if [[ -z "$selected" ]]; then
    exit 0
fi

# Extract the path
target_dir=$(echo "$selected" | awk -F' \\| ' '{print $2}')

if [[ -d "$target_dir" ]]; then
    # Send cd command to the current tmux pane
    tmux send-keys "cd '$target_dir' && clear" Enter
else
    echo "Directory not found: $target_dir"
    exit 1
fi
