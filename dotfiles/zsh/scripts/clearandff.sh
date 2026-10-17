clear-and-ff() { # clear && ff on alt + L
    clear
    fastfetch
    zle redisplay
}
zle -N clear-and-ff
bindkey '\el' clear-and-ff
