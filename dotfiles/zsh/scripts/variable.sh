export PATH="$HOME/.cargo/bin:$PATH" # cargo rust

export PATH="$PATH:$HOME/go/bin"

export PATH="$HOME/.local/bin:$PATH"

# npm's default global prefix is its own read-only /nix/store path, so `npm -g`
# fails with ENOENT unless it's pointed somewhere writable.
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$PATH:$HOME/.npm-global/bin" # npm -g installs (claude-flow, gemini, codex...)

export VISUAL=nvim

export EDITOR=nvim

export PATH="/run/wrappers/bin:$PATH"

# tmuxifier comes from nixpkgs (PATH and completions wired); just point it at personal layouts.
export TMUXIFIER_LAYOUT_PATH="$HOME/.config/tmuxifier/layouts"
