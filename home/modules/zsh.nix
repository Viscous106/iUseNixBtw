{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable            = true;
    enableCompletion  = true;
    dotDir            = ".config/zsh";   # matches Arch: $ZDOTDIR = ~/.config/zsh

    # ── oh-my-zsh ─────────────────────────────────────────────────────────────
    oh-my-zsh = {
      enable  = true;
      plugins = [ "git" "zsh-autosuggestions" "zsh-syntax-highlighting" ];
      # Theme is set by powerlevel10k plugin below; omz theme must stay empty
      # to avoid conflicts.
    };

    # ── Plugins ───────────────────────────────────────────────────────────────
    plugins = [
      # Powerlevel10k — same theme as Arch
      {
        name = "powerlevel10k";
        src  = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      # p10k instant-prompt cache
      {
        name = "powerlevel10k-config";
        src  = lib.cleanSource ../zsh;
        file = ".p10k.zsh";
      }
    ];

    # ── Autosuggestions + Syntax highlighting ─────────────────────────────────
    autosuggestion.enable    = true;
    syntaxHighlighting.enable = true;

    # ── Aliases — exact Arch set ───────────────────────────────────────────────
    shellAliases = {
      # Editor
      v       = "nvim";
      vi      = "nvim";
      n       = "nvim";

      # ls  (lsd — matching Arch)
      ls      = "lsd";
      l       = "lsd -l";
      la      = "lsd -a";
      ll      = "lsd -la";
      lla     = "lsd -la";
      lt      = "lsd --tree";

      # Better defaults
      cat     = "bat --style=numbers --color=always";
      grep    = "rg";
      find    = "fd";
      ff      = "fastfetch";
      speed   = "speedtest-cli";
      scrible = "tjournal";

      # Audio
      bluefriends = "pactl load-module module-combine-sink sink_name=combined";

      # Git
      gs      = "git status -sb";
      gd      = "git diff";
      gds     = "git diff --staged";
      ga      = "git add";
      gc      = "git commit";
      gp      = "git pull --rebase";
      gco     = "git checkout";
      lg      = "lazygit";

      # Worktree
      gwl     = "git worktree list";
      gwa     = "git worktree add";
      gwr     = "git worktree remove";
      gwp     = "git worktree prune";

      # Tmuxifier
      tx          = "tmuxifier";
      tmux-edit   = "cd ~/.config/tmuxifier/layouts && nvim";

      # NixOS
      cfg     = "nvim /persist/nixos-config/";
      rebuild = "sudo nixos-rebuild switch --flake /persist/nixos-config#nix";
      update  = "nix flake update /persist/nixos-config && rebuild";
    };

    # ── initContent — runs after oh-my-zsh and plugins are loaded ─────────────
    initContent = ''
      # ── p10k instant prompt (must be near top) ──────────────────────────────
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      # ── Startup ─────────────────────────────────────────────────────────────
      fastfetch

      # ── Thefuck / pay-respects ───────────────────────────────────────────────
      eval "$(${pkgs.pay-respects}/bin/pay-respects shell --alias)"

      # ── Command not found: custom handler ───────────────────────────────────
      command_not_found_handler() {
        echo "zsh: command not found: $1" >&2
        return 127
      }

      # ── FZF ─────────────────────────────────────────────────────────────────
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8'

      # ── Zoxide ──────────────────────────────────────────────────────────────
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"

      # ── History ─────────────────────────────────────────────────────────────
      HISTFILE="${config.xdg.configHome}/zsh/.zsh_history"
      HISTSIZE=10000
      SAVEHIST=10000
      setopt appendhistory

      # ── PATH extras ─────────────────────────────────────────────────────────
      export PATH="$PATH:$HOME/go/bin"
      export PATH="$HOME/.local/bin:$PATH"
      fpath=(~/.zsh/completions $fpath)
      autoload -Uz compinit && compinit

      # ── Tmux autostart ──────────────────────────────────────────────────────
      if [ -z "$TMUX" ] && [ -n "$DISPLAY" ]; then
        [ -f ~/.config/tmux/tmux-autostart.sh ] && bash ~/.config/tmux/tmux-autostart.sh
      fi

      # ── Pyenv ───────────────────────────────────────────────────────────────
      export PYENV_ROOT="$HOME/.pyenv"
      [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
      command -v pyenv &>/dev/null && eval "$(pyenv init - zsh)"

      # ── Tmuxifier ───────────────────────────────────────────────────────────
      export TMUXIFIER="$HOME/.config/tmuxifier"
      [ -f "$TMUXIFIER/init.sh" ] && source "$TMUXIFIER/init.sh"

      # ── Auto Python venv activation ─────────────────────────────────────────
      auto_venv_activate() {
        if [ -f "venv/bin/activate" ] && [ "$VIRTUAL_ENV" != "$(pwd)/venv" ]; then
          echo "Activating virtual environment..."
          source "venv/bin/activate"
        elif [ -n "$VIRTUAL_ENV" ] && [[ ! "$(pwd)/venv/" == "$(dirname $VIRTUAL_ENV)/"* ]]; then
          echo "Deactivating virtual environment..."
          deactivate
        fi
      }
      if [[ -z "''${chpwd_functions[(r)auto_venv_activate]}" ]]; then
        chpwd_functions+=(auto_venv_activate)
      fi

      # ── Git pretty log ───────────────────────────────────────────────────────
      gl() {
        git log --graph --all --decorate --oneline \
          --format=format:'%C(bold 141)%h%C(reset) - %C(cyan)(%ar)%C(reset) %C(white)%s%C(reset) %C(blue)- %an%C(reset)%C(bold 203)%d%C(reset)' "$@"
      }

      # ── FZF branch switcher ──────────────────────────────────────────────────
      fzb() {
        local branch
        branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null \
          | grep -v '/HEAD$' \
          | fzf --height 40% --reverse --tac --prompt="Branch > ")
        if [[ -n "$branch" ]]; then
          if [[ "$(git rev-parse --is-bare-repository 2>/dev/null)" == "true" ]]; then
            echo "Bare repo detected. Use 'gws' to switch worktrees."
          else
            git checkout "$branch"
          fi
        fi
      }

      # ── Worktree switcher ────────────────────────────────────────────────────
      gws() {
        local target
        target=$("$HOME/.config/hypr/scripts/worktree_switcher.sh" --print-only 2>/dev/null)
        [[ -n "$target" && -d "$target" ]] && cd "$target" && echo "Switched to: $(basename "$target")"
      }
      gwn() { "$HOME/.config/hypr/scripts/worktree_switcher.sh" --nvim; }

      # ── Quick branch creation ─────────────────────────────────────────────────
      gnb() {
        [[ -z "$1" ]] && echo "Usage: gnb <branch-name>" && return 1
        git checkout -b "$1"
      }

      # ── Custom keybindings ───────────────────────────────────────────────────
      bindkey '\ed' clear-screen  # Alt+D to clear

      # ── GPG TTY ─────────────────────────────────────────────────────────────
      export GPG_TTY=$(tty)

      # ── Editors ─────────────────────────────────────────────────────────────
      export VISUAL=nvim
      export EDITOR=nvim

      # ── p10k config ─────────────────────────────────────────────────────────
      [[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh
    '';

    history = {
      size       = 10000;
      save       = 10000;
      ignoreDups = true;
      share      = true;
      path       = "${config.xdg.configHome}/zsh/.zsh_history";
    };
  };

  # ── Disable starship (p10k handles the prompt) ─────────────────────────────
  programs.starship.enable = false;

  # ── Shell packages ────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    fzf
    lsd
    eza
    zoxide
    ripgrep
    fd
    bat
    jq
    yq-go
    lazygit
    delta
    unzip
    zip
    wget
    curl
    tree
    pay-respects
    fastfetch
    speedtest-cli
  ];
}
