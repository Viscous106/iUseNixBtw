{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.hyprland.homeManagerModules.default
    ./modules/zsh.nix
    ./modules/neovim.nix
    ./modules/hyprland.nix
    ./modules/hypridle.nix
    ./modules/caelestia-quickshell.nix
    ./modules/extras.nix
    ./modules/git.nix
    ./modules/kitty.nix
    ./modules/zen.nix
    ./modules/gpg.nix
    ./modules/mpv.nix
    ./modules/btop.nix
    ./modules/yazi.nix
    ./modules/cava.nix
    ./modules/wl-kbptr.nix
    ./modules/qt5ct.nix
    ./modules/qt6ct.nix
    ./modules/gtk.nix
    ./modules/icon-themes.nix
    ./modules/wallpaper-picker.nix
    ./modules/nwg-look.nix
    ./modules/nwg-displays.nix
    ./modules/apps-browsers-comms.nix
    ./modules/apps-desktop-shell.nix
    ./modules/apps-media.nix
    ./modules/apps-misc.nix
    ./modules/dev-toolchains.nix
    ./modules/fonts-extra.nix
    ./modules/neovim-deps.nix
    ./modules/python-env.nix
    ./modules/hyprwhspr.nix
    ./modules/ydotoold.nix
    ./modules/wayvr.nix
    ./modules/battery-notify.nix
  ];

  home.username      = "viscous";
  home.homeDirectory = "/home/viscous";
  home.stateVersion  = "25.05";

  # ── PATH for systemd user session (Hyprland + shell subprocesses) ─────────
  # When Hyprland runs via systemd (systemd.enable = true), exec subprocesses
  # don't inherit the interactive-shell PATH. Explicitly include NixOS package
  # dirs so the shell's execs (the `caelestia` CLI invoked from keybinds,
  # playerctl, bash shebangs, etc.) resolve.
  home.sessionPath = [
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
  ];

  programs.home-manager.enable = true;
  # ── Symlink persisted secrets and data into $HOME at every login ──────────
  home.activation.linkSecrets = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    # Ensure /persist/secrets exists or create a dummy structure for portability
    if [ ! -d /persist/secrets ]; then
       echo "Warning: /persist/secrets not found. Creating dummy structure for portability."
       $DRY_RUN_CMD mkdir -p /persist/secrets/ssh
       $DRY_RUN_CMD touch /persist/secrets/git-identity
       $DRY_RUN_CMD touch /persist/secrets/claude_api
       $DRY_RUN_CMD touch /persist/secrets/openai_api
       $DRY_RUN_CMD echo "# Add your git config here" > /persist/secrets/git-identity
       $DRY_RUN_CMD echo "# export CLAUDE_CODE_OAUTH_TOKEN=your_token_here" > /persist/secrets/claude_api
       $DRY_RUN_CMD echo "# export OPENAI_API_KEY=your_key_here" > /persist/secrets/openai_api
    fi

    # SSH keys and known_hosts
    if [ -d /persist/secrets/ssh ]; then
      $DRY_RUN_CMD mkdir -p $HOME/.ssh
      $DRY_RUN_CMD chmod 700 $HOME/.ssh
      [ -f /persist/secrets/ssh/id_ed25519 ]     && $DRY_RUN_CMD ln -sf /persist/secrets/ssh/id_ed25519     $HOME/.ssh/id_ed25519     || true
      [ -f /persist/secrets/ssh/id_ed25519.pub ] && $DRY_RUN_CMD ln -sf /persist/secrets/ssh/id_ed25519.pub $HOME/.ssh/id_ed25519.pub || true
      [ -f /persist/secrets/ssh/known_hosts ]   && $DRY_RUN_CMD ln -sf /persist/secrets/ssh/known_hosts   $HOME/.ssh/known_hosts   || true
    fi

    # Keyrings (GNOME Keyring data)
    # gnome-keyring rewrites its *.keyring files in place, so this has to
    # resolve to a real writable path — home.file/xdg.dataFile would interpose
    # a read-only /nix/store path, the same reason the Claude settings.json
    # below is linked by hand.
    #
    # Rewritten after the previous version left a dangling
    # $HOME/.local/share/keyrings/keyrings symlink behind. It had two bugs:
    #   - `ln -sfn TARGET $HOME/.local/share/keyrings` links *inside* that path
    #     whenever it already exists as a real directory rather than replacing
    #     it. That is precisely what the nested keyrings/keyrings link was.
    #   - the `if [ -d /persist/... ]` guard only fired once the target already
    #     existed, and nothing ever created it — so it could never establish the
    #     link from a clean state, and silently no-op'd forever once the target
    #     went missing.
    keyringPersist=/persist/home/viscous/.local/share/keyrings
    keyringHome=$HOME/.local/share/keyrings

    $DRY_RUN_CMD mkdir -p "$keyringPersist"
    $DRY_RUN_CMD chmod 700 "$keyringPersist"
    $DRY_RUN_CMD mkdir -p "$HOME/.local/share"

    if [ -L "$keyringHome" ]; then
      # Already a symlink (possibly dangling, possibly aimed somewhere stale):
      # re-point it. -n keeps ln from following it into its own target.
      $DRY_RUN_CMD ln -sfn "$keyringPersist" "$keyringHome"
    elif [ -d "$keyringHome" ]; then
      # A real directory: migrate its contents to /persist, then replace it.
      # The persist side is authoritative — a name already present there is
      # never overwritten, the incoming copy is set aside as .superseded so
      # nothing is destroyed silently.
      $DRY_RUN_CMD rm -f "$keyringHome/keyrings"   # stale nested link, see above
      for f in "$keyringHome"/*; do
        [ -e "$f" ] || continue                     # empty dir: the glob stays literal
        base=$(basename "$f")
        if [ -e "$keyringPersist/$base" ]; then
          $DRY_RUN_CMD mv "$f" "$f.superseded"
        else
          $DRY_RUN_CMD mv "$f" "$keyringPersist/$base"
        fi
      done
      if [ -z "$(ls -A "$keyringHome")" ]; then
        $DRY_RUN_CMD rmdir "$keyringHome"
        $DRY_RUN_CMD ln -sfn "$keyringPersist" "$keyringHome"
      else
        echo "Warning: $keyringHome still holds files after migration (see *.superseded);" \
             "leaving it as a directory rather than replacing it with the link."
      fi
    else
      $DRY_RUN_CMD ln -sfn "$keyringPersist" "$keyringHome"
    fi
  '';

  # ── Claude Code settings.json ─────────────────────────────────────────────
  # Linked here rather than with xdg.configFile because Claude Code rewrites
  # this file itself (/model, /config, enabling a plugin) using an atomic
  # write: it creates settings.json.tmp.<pid> beside the file and renames it
  # over the original. It resolves the symlink one hop to pick that
  # directory, and xdg.configFile always interposes a /nix/store path, so the
  # tmp write fails with EROFS on a read-only filesystem. A direct symlink
  # makes the first hop /persist/nixos-config/home/claude, which is writable,
  # so the rewrite lands in the git repo where it belongs.
  home.activation.linkClaudeSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p $HOME/.config/claude
    $DRY_RUN_CMD ln -sfn /persist/nixos-config/home/claude/settings.json $HOME/.config/claude/settings.json
  '';

  # ── XDG dirs ──────────────────────────────────────────────────────────────
  # ── Extra user packages required by hypr scripts ─────────────────────────
  home.packages = with pkgs; [
    claude-code  # pinned via the nixpkgs-claude input; see flake.nix
    (pkgs.lib.lowPrio python3)  # redundant vs pythonWithLibs (home/modules/python-env.nix); kept for the plain interpreter, lowPrio to resolve bin/idle3.14 collision
    pkgs.ghgrab
    inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-ide  # IDE (upstream renamed google-antigravity -> the 2.0 base app)
    inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli  # `agy` terminal CLI
    inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex  # OpenAI Codex CLI (native binary, not the node wrapper)
    pkgs.codex-whoami  # which OpenAI org/project is Codex actually billing
    pkgs.claude-whoami # which Anthropic org/workspace is Claude Code using
    obsidian
    fd
    psmisc         # provides killall
    ripgrep
    lsd           # better ls
    pyenv         # python version manager
    pulseaudio    # provides paplay
    bc            # math in shell scripts (Brightness, Volume, etc.)
    jq            # JSON parsing (WallpaperSelect, Weather, etc.)
    imagemagick   # image manipulation (WallpaperEffects)
    swappy        # screenshot annotation (ScreenShot.sh --swappy)
    wl-clipboard  # wl-copy / wl-paste (clipboard manager)
    cliphist      # clipboard history backend
    slurp         # region selection for screenshots
    grim          # screenshot tool
    awww          # wallpaper daemon (formerly swww)
    rofi          # app launcher (Super+D)
    # thunar / thunar-volman intentionally absent: they come from
    # programs.thunar in modules/desktop.nix, which is the only way the plugins
    # actually load. A second unwrapped copy here would shadow the wrapper.
    playerctl     # media controls
    pamixer       # volume control
    brightnessctl # brightness control
    pavucontrol   # audio GUI (Super+Alt+S)
    blueman       # bluetooth GUI (Super+Shift+B)
    tmux          # terminal multiplexer

    # Cursor
    bibata-cursors

    # From Nix profile
    antigen       # zsh plugin manager
    bat           # better cat
    cheese        # webcam app
    fastfetch     # system info
    gh            # github cli
    mysql84       # mysql 8.4 database
    hyprland-qtutils
    mpv           # media player
    nix-tree      # visualize nix dependencies
    wl-kbptr      # wayland keyboard pointer
    xev           # x11 event viewer
  ];

  xdg.enable = true;
  xdg.userDirs = {
    enable            = true;
    createDirectories = true;
    setSessionVariables = true;
  };

  # ── Pointer Cursor ────────────────────────────────────────────────────────
  home.pointerCursor = {
    enable  = true;   # implicit enable via this block is deprecated in home-manager
    package = pkgs.bibata-cursors;
    name    = "Bibata-Modern-Classic";
    size    = 20;
    gtk.enable = true;
    x11.enable = true;
  };
}
