{ config, pkgs, ... }:

{
  programs.zsh = {
    enable                = true;
    enableCompletion      = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    dotDir                = "${config.xdg.configHome}/zsh";

    plugins = [
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

      # ls (lsd — matching Arch setup)
      ls      = "lsd";
      l       = "lsd -l";
      ll      = "lsd -la";
      la      = "lsd -a";
      lla     = "lsd -la";
      lt      = "lsd --tree";

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

      # NixOS
      cfg     = "nvim /persist/nixos-config/";
      rebuild = "sudo nixos-rebuild switch --flake /persist/nixos-config#nix";
      update  = "nix flake update /persist/nixos-config && rebuild";

      # Misc
      ff      = "fastfetch";
      speed   = "speedtest-cli";
    };

    initContent = ''
      # ── Startup ──────────────────────────────────────────────────────────────
      fastfetch

      # ── Vi mode ──────────────────────────────────────────────────────────────
      bindkey -v
      export KEYTIMEOUT=1

      # Cursor shape: block in normal, beam in insert
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

      # ── FZF ──────────────────────────────────────────────────────────────────
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8'

      # ── Zoxide (smarter cd) ───────────────────────────────────────────────────
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh --cmd cd)"

      # ── Pay-respects (thefuck successor) ────────────────────────────────────
      eval "$(${pkgs.pay-respects}/bin/pay-respects shell --alias)"

      # ── History ───────────────────────────────────────────────────────────────
      HISTFILE="${config.xdg.configHome}/zsh/.zsh_history"
      setopt appendhistory histignorealldups sharehistory

      # ── Git pretty log ────────────────────────────────────────────────────────
      gl() {
        git log --graph --all --decorate --oneline \
          --format=format:'%C(bold 141)%h%C(reset) - %C(cyan)(%ar)%C(reset) %C(white)%s%C(reset) %C(blue)- %an%C(reset)%C(bold 203)%d%C(reset)' "$@"
      }

      # ── FZF branch switcher ────────────────────────────────────────────────────
      fzb() {
        local branch
        branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null \
          | grep -v '/HEAD$' \
          | fzf --height 40% --reverse --tac --prompt="Branch > ")
        if [[ -n "$branch" ]]; then
          if [[ "$(git rev-parse --is-bare-repository 2>/dev/null)" == "true" ]]; then
            echo "Bare repo detected. Use 'gws' to switch worktrees."
            echo "Selected branch: $branch"
          else
            git checkout "$branch"
          fi
        fi
      }

      # ── Quick branch creation ─────────────────────────────────────────────────
      gnb() {
        [[ -z "$1" ]] && echo "Usage: gnb <branch-name>" && return 1
        git checkout -b "$1"
      }

      # ── Auto Python venv activation ───────────────────────────────────────────
      auto_venv_activate() {
        if [ -f "venv/bin/activate" ] && [ "$VIRTUAL_ENV" != "$(pwd)/venv" ]; then
          echo "Activating virtual environment..."
          source "venv/bin/activate"
        elif [ -n "$VIRTUAL_ENV" ] && [[ ! "$(pwd)/" == "$(dirname $VIRTUAL_ENV)"/* ]]; then
          echo "Deactivating virtual environment..."
          deactivate
        fi
      }
      if [[ -z "''${chpwd_functions[(r)auto_venv_activate]}" ]]; then
        chpwd_functions+=(auto_venv_activate)
      fi

      # ── Tmux autostart ───────────────────────────────────────────────────────
      if [ -z "$TMUX" ] && [ -n "$DISPLAY" ]; then
        [ -f ~/.config/tmux/tmux-autostart.sh ] && bash ~/.config/tmux/tmux-autostart.sh
      fi

      # ── Pyenv ─────────────────────────────────────────────────────────────────
      export PYENV_ROOT="$HOME/.pyenv"
      [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
      command -v pyenv &>/dev/null && eval "$(pyenv init - zsh)"

      # ── Git identity from persist ─────────────────────────────────────────────
      [ -f /persist/secrets/git-identity ] && source /persist/secrets/git-identity

      # ── GPG TTY ───────────────────────────────────────────────────────────────
      export GPG_TTY=$(tty)

      # ── Editors ───────────────────────────────────────────────────────────────
      export VISUAL=nvim
      export EDITOR=nvim
    '';

    history = {
      size       = 50000;
      save       = 50000;
      ignoreDups = true;
      share      = true;
    };
  };

  # ── Starship prompt ────────────────────────────────────────────────────────
  programs.starship = {
    enable               = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$nix_shell$character";
      character = {
        success_symbol = "[❯](bold #89b4fa)";
        error_symbol   = "[❯](bold #f38ba8)";
        vimcmd_symbol  = "[❮](bold #a6e3a1)";
      };
      directory = {
        style             = "bold #cba6f7";
        truncation_length = 3;
        truncate_to_repo  = true;
      };
      git_branch = {
        symbol = " ";
        style  = "#f38ba8";
      };
      git_status = {
        style = "#f9e2af";
      };
      nix_shell = {
        symbol = "󱄅 ";
        style  = "bold #89b4fa";
      };
    };
  };

  # ── Packages available in the shell ───────────────────────────────────────
  home.packages = with pkgs; [
    fzf
    lsd           # ls replacement (matching Arch lsd aliases)
    eza           # also keep eza for 'tree' alias
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
    pay-respects      # auto-correct last command (thefuck successor)
    fastfetch        # system info on startup
    speedtest-cli    # speed alias
  ];
}
