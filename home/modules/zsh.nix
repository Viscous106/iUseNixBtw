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
      v       = "nvim";
      vi      = "nvim";
      ls      = "eza --icons --group-directories-first";
      ll      = "eza -la --icons --group-directories-first --git";
      la      = "eza -a --icons --group-directories-first";
      tree    = "eza --tree --icons --level=3";
      cat     = "bat --style=numbers --color=always";
      grep    = "rg";
      find    = "fd";
      gs      = "git status";
      gd      = "git diff";
      gl      = "git log --oneline --graph --all";
      ga      = "git add";
      gc      = "git commit";
      gp      = "git push";
      lg      = "lazygit";
      cfg     = "nvim /persist/nixos-config/";
      rebuild = "sudo nixos-rebuild switch --flake /persist/nixos-config#nix";
      update  = "nix flake update /persist/nixos-config && rebuild";
    };

    initContent = ''
      # Vi mode
      bindkey -v
      export KEYTIMEOUT=1

      # Better vi mode indicator
      function zle-keymap-select {
        if [[ ''${KEYMAP} == vicmd ]] || [[ $1 = 'block' ]]; then
          echo -ne '\e[1 q'
        elif [[ ''${KEYMAP} == main ]] || [[ ''${KEYMAP} == viins ]] || [[ ''${KEYMAP} = "" ]] || [[ $1 = 'beam' ]]; then
          echo -ne '\e[5 q'
        fi
      }
      zle -N zle-keymap-select
      echo -ne '\e[5 q'

      # FZF integration
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
      export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
      export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc,marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8'

      # Zoxide (smarter cd)
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh --cmd cd)"

      # Load git identity from persist if available
      [ -f /persist/secrets/git-identity ] && source /persist/secrets/git-identity
    '';

    history = {
      size       = 50000;
      save       = 50000;
      ignoreDups = true;
      share      = true;
    };
  };

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

  home.packages = with pkgs; [
    fzf
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
  ];
}
