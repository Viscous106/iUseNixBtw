{ config, pkgs, ... }:

{
  # ── Hyprland ──────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable          = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable        = true;
    extraPortals  = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
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
    swww             # animated wallpaper daemon (fixes the old "awww" typo)

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
    xfce.thunar
    xfce.thunar-volman
    gvfs                 # needed for Thunar trash / network mounts

    # Volume GUI
    pavucontrol

    # Misc desktop utils
    libnotify
    xdg-utils
    qt6ct                # QT theme picker
    qt5ct
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
