{ config, pkgs, inputs, ... }:

{
  # ── Hyprland ──────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable          = true;
    xwayland.enable = true;
    package = pkgs.hyprland-pinned;  # overlays/default.nix
  };

  # ── Wayland-native Chromium / Electron ────────────────────────────────────
  # Runs Chrome/Electron natively on Wayland so screen sharing uses the portal
  # + PipeWire path (XWayland capture is black under Hyprland). Also needs the
  # fake-graphical-session line in dotfiles/hypr/lua/startup_apps.lua.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  xdg.portal = {
    enable       = true;
    # Don't add xdg-desktop-portal-hyprland: programs.hyprland already does, and a
    # duplicate breaks the image clipboard.
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  # ── System-level desktop packages ─────────────────────────────────────────
  # Session plumbing only; user-facing tools live in home-manager.
  environment.systemPackages = with pkgs; [
    networkmanagerapplet   # nm-applet tray icon
    polkit_gnome           # GUI auth popups (dotfiles/hypr/scripts/Polkit-NixOS.sh)
    gvfs                   # Thunar trash / network mounts
    libnotify
    xdg-utils
    qt6Packages.qt6ct
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
  # programs.thunar sets THUNARX_DIRS; the only way plugins load on NixOS.
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin      # right-click create/extract (xarchiver backend)
      thunar-volman              # auto-handling of removable media
      thunar-media-tags-plugin   # audio tag viewing/editing + bulk rename by tag
    ];
  };

  # Persists Thunar's settings (view mode, zoom, sidebar), which otherwise reset.
  programs.xfconf.enable = true;

  # ── Bluetooth ─────────────────────────────────────────────────────────────
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable        = true;
}
