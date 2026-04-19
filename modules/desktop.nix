{ config, pkgs, ... }:

{
  # ── Hyprland ──────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable          = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable        = true;
    extraPortals  = [ pkgs.xdg-desktop-portal-hyprland ];
    config.common.default = "*";
  };

  # ── Waybar ────────────────────────────────────────────────────────────────
  programs.waybar.enable = true;

  # ── Screen locker ─────────────────────────────────────────────────────────
  programs.hyprlock.enable = true;

  # ── Notification daemon ───────────────────────────────────────────────────
  services.mako.enable = true;

  # ── System-level desktop packages ─────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    kitty
    wofi
    wl-clipboard
    grim
    slurp
    swww
    brightnessctl
    pamixer
    networkmanagerapplet
    playerctl
    libnotify
  ];

  # ── Fonts ─────────────────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" ]; })
    inter
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [ "JetBrainsMono Nerd Font Mono" ];
    sansSerif = [ "Inter" ];
    serif     = [ "Noto Serif" ];
  };

  # ── Polkit (needed for Hyprland GUI auth) ─────────────────────────────────
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;
}
