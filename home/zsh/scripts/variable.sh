export ZSH="$HOME/.config/zsh/ohmyzsh"
export ZSH_CUSTOM="$ZSH/custom"
export BROWSER=zen-browser
export fpath=(~/.zsh/completions $fpath)


export PATH="$HOME/.cargo/bin:$PATH" # cargo rust

export PYENV_ROOT="$HOME/.pyenv" # python env
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
# --no-rehash: skip the per-shell `pyenv rehash`. A rehash orphaned mid-run leaves
# ~/.pyenv/shims/.pyenv-shim behind, and every new shell then blocks 60s on that lock.
# Run `pyenv rehash` by hand after installing a package with a new entry point.
eval "$(pyenv init - --no-rehash)"

export PATH="$PATH:$HOME/go/bin"

export PATH="$HOME/.local/bin:$PATH"

export PATH="$PATH:$HOME/.npm-global/bin" # npm -g installs (claude-flow, gemini, codex...)

export VISUAL=nvim

export EDITOR=nvim

export PATH="/run/wrappers/bin:$PATH"

# tmuxifier itself comes from the nixpkgs package (home/modules/zsh.nix) now —
# PATH and completions are already wired up by nix. Just point it at the
# personal layouts that used to live inside the vendored clone.
export TMUXIFIER_LAYOUT_PATH="$HOME/.config/tmuxifier/layouts"
