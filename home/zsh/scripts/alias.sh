# all alias at one place
alias ls='lsd'
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
alias bluefriends='pactl load-module module-combine-sink sink_name=combined'
alias ff='fastfetch'
alias config='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
alias n='nvim'
alias speed='speedtest'
alias gs='git status -sb'                        # Short status
alias gd='git diff'                              # Diff
alias gp='git pull --rebase'                     # Pull with rebase
alias gfa='git fetch --all && for branch in $(git branch --format="%(refname:short)"); do git checkout $branch && git pull --rebase; done'
alias gl='git log --graph --all --decorate --oneline --format=format:"%C(bold 141)%h%C(reset) - %C(cyan)(%ar)%C(reset) %C(white)%s%C(reset) %C(blue)- %an%C(reset)%C(bold 203)%d%C(reset)"'
alias ca='config add'
alias cl="config log --graph --all --decorate --oneline --format=format:'%C(bold 141)%h%C(reset) - %C(148)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold 117)- %an%C(reset)%C(bold 203)%d%C(reset)'"
alias guvcview="guvcview -d /dev/video1"
