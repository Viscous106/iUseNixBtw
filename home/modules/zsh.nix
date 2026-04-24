{ config, pkgs, ... }:

{
  # ── ZSH Configuration ───────────────────────────────────────────────────────
  programs.zsh = {
    enable                = true;
    enableCompletion      = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    dotDir                = config.xdg.configHome + "/zsh";

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "archlinux" ];
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "zsh-fzf-history-search";
        src  = pkgs.fetchFromGitHub {
          owner = "joshskidmore";
          repo  = "zsh-fzf-history-search";
          rev   = "d1aae98ccd6ce153bbd6c9be4c6db1b99d5a7cff";
          hash  = "sha256-4Dp2ehZLO83NhdBOKV0BhYFIvieaZPqiZZZtxsXWRaQ=";
        };
      }
    ];

    shellAliases = {
      # Editor
      v       = "nvim";
      vi      = "nvim";
      n       = "nvim";

      # ls (lsd)
      ls      = "lsd";
      l       = "ls -l";
      la      = "ls -a";
      lla     = "ls -la";
      lt      = "ls --tree";

      # Better defaults
      cat     = "bat --style=numbers --color=always";
      grep    = "rg";
      find    = "fd";

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

      # NixOS / Config
      cfg     = "nvim /persist/nixos-config/";
      rebuild = "sudo nixos-rebuild switch --flake /persist/nixos-config#nix";
      update  = "nix flake update /persist/nixos-config && rebuild";
      config  = "git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME";
      ca      = "config add";
      cl      = "config log --graph --all --decorate --oneline --format=format:'%C(bold 141)%h%C(reset) - %C(148)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold 117)- %an%C(reset)%C(bold 203)%d%C(reset)'";

      # Misc
      ff      = "fastfetch";
      speed   = "speedtest";
      bluefriends = "pactl load-module module-combine-sink sink_name=combined";
      tx      = "tmuxifier";
      tmux-edit = "cd ~/.config/tmuxifier/layouts && nvim";
      scrible = "tjournal";
    };

    initContent = ''
      fastfetch

      # p10k instant prompt
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      # ── Vi mode ──────────────────────────────────────────────────────────────
      bindkey -v
      export KEYTIMEOUT=1

      # Cursor shape
      function zle-keymap-select {
        if [[ ''${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
          echo -ne '\e[1 q'
        elif [[ ''${KEYMAP} == main ]] || [[ ''${KEYMAP} == viins ]] || \
             [[ ''${KEYMAP} = "" ]] || [[ $1 = 'beam' ]]; then
          echo -ne '\e[5 q'
        fi
      }
      zle -N zle-keymap-select
      echo -ne '\e[5 q'

      # ── Custom keybindings ────────────────────────────────────────────────────
      bindkey '\ed' clear-screen     # Alt+D to clear screen
      bindkey '^H' backward-kill-word # Ctrl+Backspace (standard)
      bindkey '^[[127;5u' backward-kill-word # Ctrl+Backspace (Kitty/CSI u)
      bindkey '^[[3;5~' kill-word     # Ctrl+Delete
      bindkey '^[[1;5C' forward-word  # Ctrl+Right
      bindkey '^[[1;5D' backward-word # Ctrl+Left

      # ── FZF ──────────────────────────────────────────────────────────────────
      source <(fzf --zsh)

      # ── Zoxide ───────────────────────────────────────────────────
      eval "$(zoxide init zsh)"

      # ── Pay-respects ────────────────────────────────────
      if command -v pay-respects >/dev/null 2>&1; then
        eval "$(pay-respects zsh --alias)"
      fi

      # ── Git pretty log ────────────────────────────────────────────────────────
      unalias gl 2>/dev/null
      gl() {
        git log --graph --all --decorate --oneline \
          --format=format:'%C(bold 141)%h%C(reset) - %C(cyan)(%ar)%C(reset) %C(white)%s%C(reset) %C(blue)- %an%C(reset)%C(bold 203)%d%C(reset)' "$@"
      }

      # ── FZF branch switcher ────────────────────────────────────────────────────
      fzb() {
        local branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null |
          grep -v '/HEAD$' |
          fzf --height 40% --reverse --tac --prompt="Branch > ") 
        if [[ -n "$branch" ]]; then
          if [[ "$(git rev-parse --is-bare-repository 2>/dev/null)" == "true" ]]; then
            echo "Bare repo detected. Use 'gws' to switch worktrees."
            echo "Selected branch: $branch"
          else
            git checkout "$branch"
          fi
        fi
      }

      # ── Worktree switcher ────────────────────────────────────────────────────
      gws() {
        local target=$("$HOME/.config/hypr/scripts/worktree_switcher.sh" --print-only 2>/dev/null)
        [[ -n "$target" && -d "$target" ]] && cd "$target" && echo "Switched to: $(basename "$target")"
      }
      gwn() { "$HOME/.config/hypr/scripts/worktree_switcher.sh" --nvim; }

      # ── Quick branch creation ─────────────────────────────────────────────────
      gnb() {
        [[ -z "$1" ]] && echo "Usage: gnb <branch-name>" && return 1
        git checkout -b "$1"
      }

      # ── p10k config ──────────────────────────────────────────────────────────
      [[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh

      # ── Tmuxifier ────────────────────────────────────────────────────────────
      export TMUXIFIER="$HOME/.config/tmuxifier"
      [[ -d $TMUXIFIER ]] && source $TMUXIFIER/init.sh

      # ── Pyenv Setup ──────────────────────────────────────────────────────────
      export PYENV_ROOT="$HOME/.pyenv"
      [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
      if command -v pyenv >/dev/null 2>&1; then
        eval "$(pyenv init - zsh)"
      fi

      # ── Git identity ─────────────────────────────────────────────
      [ -f /persist/secrets/git-identity ] && source /persist/secrets/git-identity
      [ -f /persist/secrets/claude_api ] && source /persist/secrets/claude_api

      # ── GPG TTY ───────────────────────────────────────────────────────────────
      export GPG_TTY=$(tty)

      # ── Tmux autostart ───────────────────────────────────────────────────────
      if [ -z "$TMUX" ] && [ -f ~/.config/tmux/tmux-autostart.sh ]; then
          bash ~/.config/tmux/tmux-autostart.sh
      fi
    '';

    history = {
      size       = 50000;
      save       = 50000;
      ignoreDups = true;
      share      = true;
    };
  };

  # ── Helper Tools (Native Integrations) ──────────────────────────────────────
  programs.fzf.enable = true;
  programs.zoxide.enable = true;
}
