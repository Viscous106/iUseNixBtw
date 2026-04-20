{ config, pkgs, ... }:

{
  # ── Hyprland window manager ─────────────────────────────────────────────────
  wayland.windowManager.hyprland = {
    enable         = true;
    systemd.enable = true;
    extraConfig    = builtins.readFile ../hypr/hyprland.conf;
  };

  # ── Symlink config tree into ~/.config/hypr/ ────────────────────────────────
  xdg.configFile = {
    # Top-level conf files — force = true overwrites leftovers from old HM generation
    "hypr/hyprlock.conf" = { source = ../hypr/hyprlock.conf; force = true; };
    "hypr/hypridle.conf" = { source = ../hypr/hypridle.conf; force = true; };

    # configs/ — live mkOutOfStoreSymlink so scripts can write to
    # wallpaper_effects/.wallpaper_current etc. without hitting read-only fs.
    "hypr/configs".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/configs";

    # scripts/ — live editable without a rebuild
    "hypr/scripts".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/scripts";
  };

  # ── Hyprlock screen locker ──────────────────────────────────────────────────
  programs.hyprlock = {
    enable      = true;
    extraConfig = ""; # config managed via xdg.configFile above
  };

  # ── Hypridle idle daemon ────────────────────────────────────────────────────
  services.hypridle = {
    enable   = true;
    settings = {}; # config managed via xdg.configFile above
  };
}
