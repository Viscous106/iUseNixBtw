#!/usr/bin/env bash

# Git Worktree Switcher (Bare Repo Optimized)
# Shows only folder names and branch names
# Usage: worktree_switcher.sh [--nvim|--cd|--print-only]

set -e

# Check if we are inside a git repository
if ! git rev-parse --git-dir &>/dev/null; then
    echo "Error: Not a git repository."
    exit 1
fi

check_dependencies() {
    local missing=()
    for cmd in fzf git eza; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing dependencies: ${missing[*]}"
        echo "Install them with: sudo pacman -S ${missing[*]}"
        exit 1
    fi
}

# Parse worktrees into a clean list: "folder [branch] | full_path"
# We ignore the .bare folder by filtering the worktree list
list_worktrees() {
    git worktree list --porcelain | awk '
        /^worktree/ {wp=$2}
        /^branch/ {
            split(wp, parts, "/");
            folder=parts[length(parts)];
            # Skip the .bare directory if it somehow shows up as a worktree
            if (folder != ".bare") {
                print folder " [" substr($2, 12) "] | " wp
            }
        }'
}

launch_fzf() {
    local mode="$1"
    local header_text="ENTER: Select | ESC: Cancel"
    
    case "$mode" in
        nvim) header_text="ENTER: Open in Neovim | ESC: Cancel" ;;
        cd)   header_text="ENTER: Change directory | ESC: Cancel" ;;
    esac
    
    local selected
    selected=$(
        list_worktrees | fzf \
            --prompt="Switch Worktree > " \
            --height=60% \
            --layout=reverse \
            --border \
            --delimiter=' \| ' \
            --with-nth=1 \
            --preview="eza --tree --level=1 --color=always --icons \$(echo {} | awk -F' \\\\| ' '{print \$2}')" \
            --preview-window=right:50%:wrap \
            --header="$header_text"
    ) || true

    # Return only the full path (the part after the |)
    echo "$selected" | awk -F' \\| ' '{print $2}'
}

show_help() {
    cat << EOF
Git Worktree Switcher

Usage: $(basename "$0") [OPTIONS]

Options:
    --nvim        Open selected worktree in Neovim with Telescope (default)
    --cd          Print cd command for shell integration
    --print-only  Only print the selected path (for shell functions)
    -h, --help    Show this help message

Examples:
    $(basename "$0")              # Default: open in Neovim
    $(basename "$0") --print-only # Print path for shell cd
EOF
}

main() {
    local mode="nvim"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --nvim) mode="nvim"; shift ;;
            --cd) mode="cd"; shift ;;
            --print-only) mode="print"; shift ;;
            -h|--help) show_help; exit 0 ;;
            *) echo "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done
    
    check_dependencies

    local target_dir
    target_dir=$(launch_fzf "$mode")

    if [[ -z "$target_dir" ]]; then
        exit 0
    fi

    if [[ ! -d "$target_dir" ]]; then
        echo "Error: Directory not found: $target_dir"
        exit 1
    fi

    case "$mode" in
        nvim)
            cd "$target_dir"
            if command -v nvim &>/dev/null; then
                nvim -c "lua require('telescope.builtin').find_files()"
            else
                echo "Neovim not found. Changed to: $target_dir"
            fi
            ;;
        cd)
            echo "cd '$target_dir'"
            ;;
        print)
            echo "$target_dir"
            ;;
    esac
}

main "$@"
