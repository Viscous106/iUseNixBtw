# fzf's key bindings aren't sourced here: programs.fzf already does, and a second source
# would race atuin's init for Ctrl+R (atuin owns it; home/shell/atuin.nix).

# Move fzf-cd-widget from Alt+C to Alt+R. Still works: this file runs at order
# 1000, after fzf has defined the widget at 910.
bindkey -r '^[c'                    # unbind Alt+C
bindkey '^[r' fzf-cd-widget         # bind Alt+R -> fuzzy cd into subdirectory
