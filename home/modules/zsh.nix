{ config, pkgs, ... }:

{
  # ── ZSH Configuration ───────────────────────────────────────────────────────
  # Prompt is Starship (not powerlevel10k — Arch switched away from p10k).
  # Most of the actual config is the real scripts from Arch's modular
  # ~/.config/zsh/scripts/, live-editable at /persist/nixos-config/home/zsh/.
  programs.zsh = {
    enable                = true;
    enableCompletion      = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    dotDir                = config.xdg.configHome + "/zsh";

    oh-my-zsh = {
      enable  = true;
      plugins = [ "git" "archlinux" ]; # zsh-autosuggestions/zsh-syntax-highlighting
                                        # are the standalone modules above instead
    };

    # Bonus plugin, not part of Arch's setup but harmless/additive — kept.
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

    initContent = ''
      # ── Custom keybindings ──────────────────────────────────────────────────
      # Kitty/tmux Ctrl+Backspace CSI-u fix + Nix-side additions — not from
      # Arch, no equivalent there, kept as harmless standalone terminal fixes.
      bindkey -e                     # Emacs mode (standard shell feel)
      bindkey '\ed' clear-screen     # Alt+D to clear screen
      bindkey '^H' backward-kill-word # Ctrl+Backspace (standard)
      bindkey '^[[127;5u' backward-kill-word # Ctrl+Backspace (Kitty/CSI u)
      bindkey '^[[3;5~' kill-word     # Ctrl+Delete
      bindkey '^[[1;5C' forward-word  # Ctrl+Right
      bindkey '^[[1;5D' backward-word # Ctrl+Left

      # ── Real Arch scripts, sourced verbatim (live-editable) ─────────────────
      for _f in \
        variable android-spawn clearandff git_worspace_tmux \
        gpg-git keybinds optimisation startup \
        tmux_copy_wayland_fix tmux_start
      do
        [ -f "$HOME/.config/zsh/scripts/$_f.sh" ] && source "$HOME/.config/zsh/scripts/$_f.sh"
      done
      unset _f

      # ── Pay-respects ─────────────────────────────────────────────────────────
      # `thefuck` was removed from nixpkgs (Python 3.12+ incompatible) — Arch
      # still has it, but nixpkgs forces pay-respects as the replacement here.
      if command -v pay-respects >/dev/null 2>&1; then
        eval "$(pay-respects zsh --alias)"
      fi

      # ── Git identity / API keys (portable-drive secrets, not from Arch —
      # Arch sets git identity via a plain ~/.gitconfig instead) ─────────────
      [ -f /persist/secrets/git-identity ] && source /persist/secrets/git-identity
      [ -f /persist/secrets/claude_api ] && source /persist/secrets/claude_api

      fastfetch
    '';
  };

  # ── Aliases ported verbatim from ~/.config/zsh/scripts/alias.sh, plus a few
  # Nix-side additions (cfg/rebuild/update, better ls/cat/grep/find) ─────────
  home.shellAliases = {
    # From Arch's alias.sh
    ls      = "lsd";
    l       = "ls -l";
    la      = "ls -a";
    lla     = "ls -la";
    lt      = "ls --tree";
    bluefriends = "pactl load-module module-combine-sink sink_name=combined";
    ff      = "fastfetch";
    config  = "git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME";
    n       = "nvim";
    speed   = "speedtest";
    gs      = "git status -sb";
    gd      = "git diff";
    gp      = "git pull --rebase";
    gl      = "git log --graph --all --decorate --oneline --format=format:'%C(bold 141)%h%C(reset) - %C(cyan)(%ar)%C(reset) %C(white)%s%C(reset) %C(blue)- %an%C(reset)%C(bold 203)%d%C(reset)'";
    ca      = "config add";
    cl      = "config log --graph --all --decorate --oneline --format=format:'%C(bold 141)%h%C(reset) - %C(148)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold 117)- %an%C(reset)%C(bold 203)%d%C(reset)'";

    # Nix-side additions, not from Arch's alias.sh, kept as harmless extras
    v       = "nvim";
    vi      = "nvim";
    cat     = "bat --style=numbers --color=always";
    grep    = "rg";
    find    = "fd";
    gds     = "git diff --staged";
    ga      = "git add";
    gc      = "git commit";
    gco     = "git checkout";
    lg      = "lazygit";
    gwl     = "git worktree list";
    gwa     = "git worktree add";
    gwr     = "git worktree remove";
    gwp     = "git worktree prune";
    cfg     = "nvim /persist/nixos-config/";
    rebuild = "sudo nixos-rebuild switch --flake /persist/nixos-config#nix";
    update  = "nix flake update /persist/nixos-config && rebuild";
    tx      = "tmuxifier";
    "tmux-edit" = "cd ~/.config/tmuxifier/layouts && nvim";
    scrible = "tjournal";
  };

  # ── zshenv / zprofile — ported verbatim from Arch ────────────────────────
  programs.zsh.envExtra = ''
    export PATH="/run/wrappers/bin:$PATH"
    . "$HOME/.cargo/env"
    export STARSHIP_CONFIG="$HOME/.config/zsh/starship.toml"
    export CLAUDE_CONFIG_DIR="$HOME/.config/claude"
  '';
  programs.zsh.profileExtra = ''
    if [ -z "$WAYLAND_DISPLAY" ] && [ -S "/run/user/$(id -u)/wayland-1" ]; then
      export WAYLAND_DISPLAY=wayland-1
    fi
    export PATH="$PATH:$HOME/.local/bin"
  '';

  # ── Starship prompt config — raw file, live-editable ─────────────────────
  xdg.configFile."zsh/starship.toml".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/zsh/starship.toml";

  # ── Modular scripts — raw files, live-editable ───────────────────────────
  xdg.configFile."zsh/scripts".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/zsh/scripts";

  # ── Helper Tools (Native Integrations) ──────────────────────────────────────
  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  home.packages = [ pkgs.starship pkgs.pay-respects ];
}
