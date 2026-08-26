source <(fzf --zsh) # Set-up FZF key bindings (CTRL R for fuzzy history finder)

# Move fzf-cd-widget from Alt+C to Alt+R (must run after `fzf --zsh` above)
bindkey -r '^[c'                    # unbind Alt+C
bindkey '^[r' fzf-cd-widget         # bind Alt+R -> fuzzy cd into subdirectory
