{ config, pkgs, ... }:

{
  # ── ZSH ─────────────────────────────────────────────────────────────────────
  # Prompt is Starship; most config lives in dotfiles/zsh/scripts (sourced below).
  programs.zsh = {
    enable                = true;
    enableCompletion      = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    dotDir                = config.xdg.configHome + "/zsh";

    oh-my-zsh = {
      enable  = true;
      plugins = [ "git" ]; # autosuggestions/highlighting: HM options above
    };

    initContent = ''
      # ── Custom keybindings ──────────────────────────────────────────────────
      # Kitty/tmux Ctrl+Backspace CSI-u fix and other standalone terminal fixes.
      bindkey -e                     # Emacs mode (standard shell feel)
      bindkey '\ed' clear-screen     # Alt+D to clear screen
      bindkey '^H' backward-kill-word # Ctrl+Backspace (standard)
      bindkey '^[[127;5u' backward-kill-word # Ctrl+Backspace (Kitty/CSI u)
      bindkey '^[[3;5~' kill-word     # Ctrl+Delete
      bindkey '^[[1;5C' forward-word  # Ctrl+Right
      bindkey '^[[1;5D' backward-word # Ctrl+Left

      # ── Live-editable shell scripts (dotfiles/zsh/scripts) ───────────────────────
      for _f in \
        variable clearandff git-workspace-tmux \
        gpg-git keybinds shell-init \
        tmux_copy_wayland_fix cmd-notify
      do
        [ -f "$HOME/.config/zsh/scripts/$_f.sh" ] && source "$HOME/.config/zsh/scripts/$_f.sh"
      done
      unset _f

      # ── rsync-based cp/mv (progress bars, resumable) ─────────────────────────
      # Functions, not aliases; any flag or <2 args goes to the real binary (completion and compinit probe mv).
      _rsync_transfer() {
        local remove=$1 name=cp; shift
        [[ $remove == 1 ]] && name=mv
        for a in "$@"; do
          [[ $a == -* ]] && { command "$name" "$@"; return }
        done
        (( $# < 2 )) && { command "$name" "$@"; return }
        local dst=''${@[-1]}
        local srcs=(''${@[1,-2]})
        local s missing=0
        for s in "''${srcs[@]}"; do
          if [[ ! -e $s ]]; then
            print -u2 "$name: cannot stat '$s': No such file or directory"
            missing=1
          fi
        done
        (( missing )) && return 1
        if (( ''${#srcs} == 1 )) && [[ -d ''${srcs[1]} && ! -d $dst ]]; then
          srcs[1]="''${srcs[1]%/}/"
        fi
        if [[ $remove == 1 ]]; then
          # Prune empty dirs only under the source dirs: `find` with zero paths
          # would default to cwd (this once deleted refs/ in ~/.cache/nix repos).
          local prune=()
          for s in "''${srcs[@]}"; do [[ -d $s ]] && prune+=("$s"); done
          rsync -ahP --info=progress2,stats2 --stats --remove-source-files "''${srcs[@]}" "$dst" || return
          (( ''${#prune} )) && find "''${prune[@]}" -depth -type d -empty -delete 2>/dev/null
          return 0
        else
          rsync -ahP --info=progress2,stats2 --stats "''${srcs[@]}" "$dst"
        fi
      }
      cp() { _rsync_transfer 0 "$@" }
      mv() { _rsync_transfer 1 "$@" }

      # cd with a zoxide fallback for a lone non-path arg (not `zoxide init --cmd cd`, which takes over
      # z/zi and all of cd's args). Needs `z`, so it must follow the scripts loop above.
      cd() {
        if (( $# == 1 )) && [[ -n $1 && $1 != -* ]]; then
          builtin cd -- "$1" 2>/dev/null && return
          z "$1" 2>/dev/null && return
          builtin cd -- "$1"
        else
          builtin cd "$@"
        fi
      }

      # ── Pay-respects ─────────────────────────────────────────────────────────
      # nixpkgs dropped thefuck; this eval installs command_not_found_handler (nix-locate wired below).
      if command -v pay-respects >/dev/null 2>&1; then
        eval "$(pay-respects zsh --alias)"
      fi

      # ── Git identity / API keys (portable-drive secrets, not from Arch —
      # Arch sets git identity via a plain ~/.gitconfig instead) ─────────────
      [ -f /persist/secrets/git-identity ] && source /persist/secrets/git-identity
      [ -f /persist/secrets/claude_api ] && source /persist/secrets/claude_api
      [ -f /persist/secrets/openai_api ] && source /persist/secrets/openai_api

      fastfetch
    '';
  };

  # ── Aliases ─────────────────────────────────────────────────────────────────
  home.shellAliases = {
    ls      = "eza --icons";
    l       = "ls -l";
    la      = "ls -a";
    lla     = "ls -la";
    lt      = "ls --tree";
    bluefriends = "pactl load-module module-combine-sink sink_name=combined";
    ff      = "fastfetch";
    config  = "git -C /persist/nixos-config";
    n       = "nvim";
    speed   = "speedtest";
    gs      = "git status -sb";
    gd      = "git diff";
    gp      = "git pull --rebase";
    gl      = "git log --graph --all --decorate --oneline --format=format:'%C(bold 141)%h%C(reset) - %C(cyan)(%ar)%C(reset) %C(white)%s%C(reset) %C(blue)- %an%C(reset)%C(bold 203)%d%C(reset)'";
    ca      = "config add";
    cl      = "config log --graph --all --decorate --oneline --format=format:'%C(bold 141)%h%C(reset) - %C(148)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold 117)- %an%C(reset)%C(bold 203)%d%C(reset)'";

    v       = "nvim";
    vi      = "nvim";
    cat     = "bat --style=numbers --color=always";
    grep    = "rg";
    find    = "fd";
    gds     = "git diff --staged";
    ga      = "git add";
    gc      = "git commit";
    gco     = "git checkout";
    gwl     = "git worktree list";
    gwa     = "git worktree add";
    gwr     = "git worktree remove";
    gwp     = "git worktree prune";
    gfa     = "git fetch --all && for branch in $(git branch --format=\"%(refname:short)\"); do git checkout $branch && git pull --rebase; done";
    cfg     = "nvim /persist/nixos-config/";
    # No `#nix` suffix: that's the USB host and breaks the NVMe laptop's boot.
    # Bare --flake picks by hostname (hosts/usb.nix "nix", hosts/nvme.nix "laptop").
    rebuild = "sudo nixos-rebuild switch --flake /persist/nixos-config";
    update  = "nix flake update /persist/nixos-config && rebuild";
    tx      = "tmuxifier";
    "tmux-edit" = "cd ~/.config/tmuxifier/layouts && nvim";
    scrible = "tjournal";
  };

  # ── zshenv / zprofile ───────────────────────────────────────────────────
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

  # ── Helper tools ────────────────────────────────────────────────────────────
  programs.fzf.enable = true;
  # Empty = fzf skips its Ctrl-R binding, so atuin owns it without a load-order
  # race. Ctrl-T and Alt-C are untouched.
  programs.fzf.historyWidget.zsh.command = "";
  programs.zoxide.enable = true;

  # nix-index-database supplies the prebuilt DB pay-respects queries. Its zsh
  # hook would define a second command_not_found_handler racing pay-respects'.
  programs.nix-index.enableZshIntegration = false;
  home.packages = [ pkgs.starship pkgs.pay-respects pkgs.tmuxifier ];
}
