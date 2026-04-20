{ config, pkgs, ... }:

{
  # ── Hyprland window manager ─────────────────────────────────────────────────
  # The `enable` flag installs the package, sets up the systemd socket/service,
  # and wires up XDG portals.  We deliberately leave `settings` empty and let
  # our hand-crafted config files (sourced via extraConfig) do all the work so
  # that the result is identical to the previous Arch Linux setup.
  wayland.windowManager.hyprland = {
    enable         = true;
    systemd.enable = true;

    # The entire config is expressed as plain .conf files inside
    # ~/.config/hypr/ (symlinked by xdg.configFile below).
    # We only need to tell Hyprland where the entry-point is.
    extraConfig = builtins.readFile ../hypr/hyprland.conf;
  };

  # ── Symlink config tree into ~/.config/hypr/ ────────────────────────────────
  # Every file/directory here is managed by Home Manager; editing them in
  # /persist/nixos-config/home/hypr/ and rebuilding will apply changes.

  xdg.configFile = {
    # ── Top-level conf files ────────────────────────────────────────────────
    "hypr/hyprlock.conf".source = ../hypr/hyprlock.conf;
    "hypr/hypridle.conf".source = ../hypr/hypridle.conf;

    # ── configs/ directory ──────────────────────────────────────────────────
    "hypr/configs".source = ../hypr/configs;

    # ── scripts/ directory ──────────────────────────────────────────────────
    # Copy the scripts so they stay executable; we use mkOutOfStoreSymlink to
    # allow in-place editing without a full rebuild.
    "hypr/scripts".source =
      config.lib.file.mkOutOfStoreSymlink
        "/persist/nixos-config/home/hypr/scripts";
  };

  # ── Hyprlock screen locker ──────────────────────────────────────────────────
  programs.hyprlock = {
    enable      = true;
    # Config is managed via xdg.configFile above (hypr/hyprlock.conf),
    # so we use extraConfig = "" to prevent Home Manager from generating
    # a duplicate config that would conflict.
    extraConfig = "";
  };

  # ── Hypridle idle daemon ────────────────────────────────────────────────────
  services.hypridle = {
    enable      = true;
    # Same pattern — config file is symlinked above.
    # We pass an empty settings block so the service is enabled and
    # the correct xdg path is used automatically by hypridle.
    settings    = {};
  };
}
