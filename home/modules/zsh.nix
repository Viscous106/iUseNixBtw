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

      # ── rsync-based cp/mv (progress bars, resumable) ─────────────────────────
      # Defined as functions, not shellAliases: an alias named cp/mv would
      # alias-expand before a same-named function is ever looked up, silently
      # shadowing it. Two rsync gotchas needed fixing too:
      #   1. Without a trailing slash on a lone source dir, rsync always
      #      nests it under dst (dst/src/...) even when dst doesn't exist
      #      yet — unlike cp/mv, where dst becomes a renamed copy of src in
      #      that case. Fixed by adding the trailing slash ourselves when
      #      there's exactly one source dir and dst isn't an existing dir.
      #   2. `mv --remove-source-files` deletes files but never the
      #      now-empty source directory tree it leaves behind, so a plain
      #      rsync alias doesn't really "move" a directory.
      #   3. A missing source used to fall straight through to rsync,
      #      which dumps a whole stats block and a cryptic "link_stat ...
      #      No such file or directory" for what should just be a plain
      #      "cannot stat" error like real cp/mv give — checked up front now.
      _rsync_transfer() {
        local remove=$1 name=cp; shift
        [[ $remove == 1 ]] && name=mv
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
          rsync -ahP --info=progress2,stats2 --stats --remove-source-files "''${srcs[@]}" "$dst" \
            && find "''${srcs[@]}" -depth -type d -empty -delete 2>/dev/null
        else
          rsync -ahP --info=progress2,stats2 --stats "''${srcs[@]}" "$dst"
        fi
      }
      cp() { _rsync_transfer 0 "$@" }
      mv() { _rsync_transfer 1 "$@" }

      # ── cd with a zoxide fallback ────────────────────────────────────────────
      # A real path still goes to builtin cd, so flags, `cd -`, `cd old new`
      # and CDPATH all behave exactly as before. Only a lone argument that
      # isn't a usable path falls through to a zoxide jump, so `cd nixos-config`
      # lands in /persist/nixos-config instead of erroring; if zoxide has no
      # match either, builtin cd runs again just to print its normal error.
      # A function, not an alias, for the same reason as cp/mv above, and
      # deliberately not `zoxide init --cmd cd`: that variant replaces `z`/`zi`
      # and hands cd's whole argument handling over to zoxide. It has to come
      # after optimisation.sh has sourced `zoxide init zsh` (the scripts loop
      # above), which is where `z` is defined.
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
      # `thefuck` was removed from nixpkgs (Python 3.12+ incompatible) — Arch
      # still has it, but nixpkgs forces pay-respects as the replacement here.
      # This eval is what installs command_not_found_handler; the nix-locate it
      # consults for "which package has this binary" is wired up below.
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
    # On Arch this managed ~/.dotfiles as a bare repo over $HOME. On NixOS the
    # config itself is a normal git repo, so `config` just operates on it directly.
    config  = "git -C /persist/nixos-config";
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
    # Rescued from home/zsh/scripts/alias.sh before it was deleted: that file was
    # never in the source loop above, so these two had never actually worked.
    gfa     = "git fetch --all && for branch in $(git branch --format=\"%(refname:short)\"); do git checkout $branch && git pull --rebase; done";
    guvcview = "guvcview -d /dev/video1";  # /dev/video0 is the metadata node
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

  # nix-locate, the package-lookup backend pay-respects shells out to when a
  # command is not found. The flake input (see flake.nix) carries a prebuilt
  # database, so this needs no `nix-index` crawl and no cron job to refresh it.
  #
  # The module defaults `enable` and `symlinkToCacheHome` to true, which is what
  # drops the database at ~/.cache/nix-index/files where nix-locate looks for
  # it. Only the zsh integration has to be turned off by hand: it sources
  # nix-index's own command-not-found.sh, which defines command_not_found_handler
  # — the exact hook pay-respects claims in initExtra above. Both modules append
  # to the same zsh init, so leaving this on means whichever lands last silently
  # wins. We want the database, not a second handler racing for the hook.
  programs.nix-index.enableZshIntegration = false;
  # tmuxifier is a real nixpkgs package now (was vendored as a raw git clone
  # from Arch before that was true) — see home/tmuxifier for just the
  # personal layouts that vendoring left behind.
  home.packages = [ pkgs.starship pkgs.pay-respects pkgs.tmuxifier ];
}
