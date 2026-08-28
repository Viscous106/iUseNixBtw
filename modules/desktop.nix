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
    package = inputs.hyprland.packages.${pkgs.system}.hyprland.override {
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

  # ── Waybar ────────────────────────────────────────────────────────────────
  programs.waybar.enable = true;

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
    networkmanagerapplet
    blueman

    # Notifications (swaync = SwayNC, a nicer notification + control-centre)
    swaynotificationcenter

    # Screen locker + idle daemon
    hyprlock
    hypridle

    # Polkit agent (GUI auth popups)
    polkit_gnome

    # File manager
    thunar
    thunar-volman
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

  # ── Bluetooth ─────────────────────────────────────────────────────────────
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable        = true;
}
