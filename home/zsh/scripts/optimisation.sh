HISTFILE=~/.config/zsh/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

# Starship + zoxide init — cached so we don't fork them on every shell.
_zi_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-init"
[[ -d $_zi_cache ]] || mkdir -p $_zi_cache
for _t in starship zoxide; do
    command -v $_t >/dev/null || continue                 # skip if not installed
    _f="$_zi_cache/$_t.zsh"
    [[ -s $_f && ! $(command -v $_t) -nt $_f ]] || $_t init zsh > $_f
    source $_f
done
unset _t _f _zi_cache

zmodload zsh/complete

