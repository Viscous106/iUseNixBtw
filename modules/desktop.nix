{ config, pkgs, inputs, ... }:

{
  # ── Hyprland ──────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable          = true;
    xwayland.enable = true;
    # wrapRuntimeDeps disabled here too: same reasoning as home/modules/hyprland.nix
    # -- this is the system-level programs.hyprland package (separate from
    # home-manager's wayland.windowManager.hyprland), and it also pulled in the
    # broken hyprland-guiutils build unless overridden here independently.
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland.override {
      wrapRuntimeDeps = false;
      # Hyprland's CMakeLists.txt requires glaze 7.x (find_package(glaze 7...<8)),
      # but current nixpkgs' glaze is 8.1.0 -- pinned back to 7.2.0 for this
      # build only (doesn't affect the system-wide glaze package).
      glaze-hyprland = pkgs.glaze.overrideAttrs (old: {
        version = "7.2.0";
        src = pkgs.fetchFromGitHub {
          owner = "stephenberry";
          repo = "glaze";
          rev = "v7.2.0";
          hash = "sha256-f3NVRi3SXKo42hn0WCw7JsOK3EkdOVJIcuzhPorKjFY=";
        };
      });
    };
  };

  xdg.portal = {
    enable       = true;
    # xdg-desktop-portal-hyprland is added automatically by programs.hyprland.enable;
    # adding it again here causes portal dispatcher conflicts that break image clipboard.
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  # ── System-level desktop packages ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # Terminal
    kitty

    # Launcher / menus
    wofi
    cliphist         # clipboard history manager (wofi integration)

    # Clipboard
    wl-clipboard

    # Screenshots
    grim
    slurp
    swappy           # screenshot annotation

    # Wallpaper
    awww             # animated wallpaper daemon (swww was renamed to awww in nixpkgs)

    # Brightness / volume / media
    brightnessctl
    pamixer
    playerctl

    # Network / Bluetooth tray
    networkmanagerapplet   # provides nm-applet
    # NOTE: lua/startup_apps.lua also execs `nm-tray`, which Arch has but NixOS
    # cannot provide — nixpkgs removed nm-tray on 2025-08-30 ("only works with
    # Plasma 5"); referencing it now throws at eval time. The exec-once simply
    # no-ops here. Nothing is lost: `nm-applet --indicator`, launched on the line
    # above it in startup_apps.lua, provides the same NetworkManager tray icon.
    blueman

    # Notifications (swaync = SwayNC, a nicer notification + control-centre)
    swaynotificationcenter

    # Screen locker + idle daemon
    hyprlock
    hypridle

    # Polkit agent (GUI auth popups)
    polkit_gnome

    # File manager: NOT listed here — see programs.thunar below. Installing the
    # thunar package plainly is what broke plugins: thunar only scans
    # $THUNARX_DIRS, or its OWN store lib/thunarx-3 when that is unset. Its store
    # path ships just apr/sbr/uca/wallpaper, so thunar-archive-plugin sitting in
    # the user profile was never loaded — right-click "Extract Here" simply did
    # not exist. programs.thunar builds a wrapper with THUNARX_DIRS pointing at
    # the plugins listed there.
    gvfs                 # needed for Thunar trash / network mounts

    # Volume GUI
    pavucontrol

    # Misc desktop utils
    libnotify
    xdg-utils
    qt6Packages.qt6ct    # QT theme picker
  ];

  # ── Fonts ─────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    inter
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [ "JetBrainsMono Nerd Font Mono" ];
    sansSerif = [ "Inter" ];
    serif     = [ "Noto Serif" ];
  };

  # ── Polkit ────────────────────────────────────────────────────────────────
  security.polkit.enable = true;

  # ── Thunar (GVFS daemon for trash / mounts) ───────────────────────────────
  services.gvfs.enable = true;
  services.tumbler.enable = true;   # thumbnail service for Thunar

  # ── Thunar ────────────────────────────────────────────────────────────────
  # programs.thunar wraps thunar with THUNARX_DIRS set to these plugins' output
  # dirs. That is the only way plugins load on NixOS — see the note in
  # environment.systemPackages above.
  programs.thunar = {
    enable = true;
    # These three moved out of pkgs.xfce to top-level in nixpkgs; referencing
    # them through pkgs.xfce still works but emits a deprecation warning.
    plugins = with pkgs; [
      thunar-archive-plugin      # right-click create/extract (xarchiver is the
                                 # backend, already installed in
                                 # home/modules/apps-desktop-shell.nix)
      thunar-volman              # auto-handling of removable media
      thunar-media-tags-plugin   # audio tag viewing/editing + bulk rename by tag
    ];
  };

  # Thunar's bulk-rename and "open terminal here" both shell out; xfconf stores
  # Thunar's own settings (view mode, zoom, sidebar width) which otherwise reset
  # every launch.
  programs.xfconf.enable = true;

  # ── skwd-wall — wallpaper selector on SUPER+W ─────────────────────────────
  # Installs skwd-wall (the Quickshell selector UI), the `skwd` CLI, and
  # skwd-daemon, which is what actually renders the wallpaper. The daemon
  # replaces awww/mpvpaper for this purpose, so nothing else may paint the
  # background: caelestia already has background.wallpaperEnabled = false, and
  # the awww restore was dropped from startup_apps.lua.
  #
  # The module also does systemd.packages = [ skwd ], which INSTALLS
  # skwd-daemon.service but cannot start it here: the unit is
  # WantedBy=graphical-session.target, and this session never reaches that
  # target (Hyprland is started directly, no uwsm). startup_apps.lua launches
  # the daemon instead — the same workaround caelestia needs.
  programs.skwd-wall.enable = true;

  # ── Bluetooth ─────────────────────────────────────────────────────────────
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable        = true;
}
