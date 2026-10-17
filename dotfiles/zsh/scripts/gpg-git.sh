# The terminal gpg password window loader
if [[ -t 0 ]]; then
    export GPG_TTY=$(tty)
    stty -ixon
fi
