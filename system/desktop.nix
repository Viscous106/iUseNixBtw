{ config, pkgs, inputs, ... }:

{
  # ── Hyprland ──────────────────────────────────────────────────────────────
  programs.hyprland = {
    enable          = true;
    xwayland.enable = true;
    package = pkgs.hyprland-pinned;  # overlays/default.nix
  };

  # ── Wayland-native Chromium / Electron ────────────────────────────────────
  # google-chrome's nixpkgs wrapper appends its Wayland flags only when this is
  # set — the wrapper literally contains:
  #   ${NIXOS_OZONE_WL:+${WAYLAND_DISPLAY:+--ozone-platform-hint=auto ...}}
  # Nothing in this config set it, so Chrome always started on XWayland. There,
  # getDisplayMedia() uses Chromium's X11 screen capturer, which under Hyprland
  # has no real root window to read — so "share your entire screen" produced a
  # failed/black capture on proctored tests and video calls. On Wayland Chrome
  # takes the xdg-desktop-portal ScreenCast + PipeWire path instead, which is the
  # one xdg-desktop-portal-hyprland actually implements.
  # Paired with the nixos-fake-graphical-session.target line in
  # dotfiles/hypr/lua/startup_apps.lua: this picks the right capture path, that one
  # makes the portal it depends on able to start at all. Both are required.
  # Also applies to other Chromium/Electron apps (VS Code, Discord, …) — the
  # standard NixOS switch for running them natively on Wayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  xdg.portal = {
    enable       = true;
    # xdg-desktop-portal-hyprland is added automatically by programs.hyprland.enable;
    # adding it again here causes portal dispatcher conflicts that break image clipboard.
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  # ── System-level desktop packages ─────────────────────────────────────────
  # User-facing desktop tools (terminal, screenshot, clipboard, media keys) are
  # in home-manager; only session plumbing lives here.
  environment.systemPackages = with pkgs; [
    networkmanagerapplet   # nm-applet tray icon
    polkit_gnome           # GUI auth popups (scripts/Polkit-NixOS.sh)
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
                                 # home/desktop/utils.nix)
      thunar-volman              # auto-handling of removable media
      thunar-media-tags-plugin   # audio tag viewing/editing + bulk rename by tag
    ];
  };

  # Thunar's bulk-rename and "open terminal here" both shell out; xfconf stores
  # Thunar's own settings (view mode, zoom, sidebar width) which otherwise reset
  # every launch.
  programs.xfconf.enable = true;

  # ── Bluetooth ─────────────────────────────────────────────────────────────
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable        = true;
}
