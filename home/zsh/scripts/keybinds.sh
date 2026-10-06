# fzf's key bindings are NOT sourced here. `programs.fzf.enable` in
# home/modules/zsh.nix already runs `source <(fzf --zsh)` at home-manager's
# mkOrder 910. Re-sourcing it from this file would run it again at order 1000
# — the same bucket as atuin's init — leaving Ctrl+R to whichever happened to
# load last. Atuin owns Ctrl+R now; see home/modules/atuin.nix.

# Move fzf-cd-widget from Alt+C to Alt+R. Still works: this file runs at order
# 1000, after fzf has defined the widget at 910.
bindkey -r '^[c'                    # unbind Alt+C
bindkey '^[r' fzf-cd-widget         # bind Alt+R -> fuzzy cd into subdirectory
