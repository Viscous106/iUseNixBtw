{ config, pkgs, inputs, ... }:

{
  imports = [
    ./modules/zsh.nix
    ./modules/neovim.nix
    ./modules/hyprland.nix
    ./modules/hypridle.nix
    ./modules/waybar.nix
    ./modules/extras.nix
    ./modules/git.nix
    ./modules/kitty.nix
    ./modules/zen.nix
    ./modules/gpg.nix
  ];

  home.username      = "viscous";
  home.homeDirectory = "/home/viscous";
  home.stateVersion  = "25.05";

  programs.home-manager.enable = true;

  # ── Symlink persisted secrets and data into $HOME at every login ──────────
  home.activation.linkSecrets = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    # SSH keys and known_hosts
    if [ -d /persist/secrets/ssh ]; then
      $DRY_RUN_CMD mkdir -p $HOME/.ssh
      $DRY_RUN_CMD ln -sf /persist/secrets/ssh/id_ed25519     $HOME/.ssh/id_ed25519     || true
      $DRY_RUN_CMD ln -sf /persist/secrets/ssh/id_ed25519.pub $HOME/.ssh/id_ed25519.pub || true
      $DRY_RUN_CMD [ -f /persist/secrets/ssh/known_hosts ] && $DRY_RUN_CMD ln -sf /persist/secrets/ssh/known_hosts $HOME/.ssh/known_hosts || true
      $DRY_RUN_CMD chmod 700 $HOME/.ssh
      chmod 600 $HOME/.ssh/id_ed25519 2>/dev/null || true
    fi

    # Keyrings (GNOME Keyring data)
    $DRY_RUN_CMD mkdir -p $HOME/.local/share
    if [ -d /persist/home/viscous/.local/share/keyrings ]; then
      $DRY_RUN_CMD ln -sfn /persist/home/viscous/.local/share/keyrings $HOME/.local/share/keyrings || true
    fi
  '';

  # ── XDG dirs ──────────────────────────────────────────────────────────────
  # ── Extra user packages required by hypr scripts ─────────────────────────
  home.packages = with pkgs; [
    unstable.claude-code
    unstable.gemini-cli
    inputs.antigravity.packages.${pkgs.system}.google-antigravity
    psmisc         # provides killall
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
    swaynotificationcenter  # notification daemon (swaync CLI)
    thunar        # file manager
    xfce.thunar-volman # volume manager for Thunar
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
    package = pkgs.bibata-cursors;
    name    = "Bibata-Modern-Classic";
    size    = 20;
    gtk.enable = true;
    x11.enable = true;
  };
}
