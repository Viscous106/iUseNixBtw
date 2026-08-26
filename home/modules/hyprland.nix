{ config, pkgs, ... }:

{
  # ── Hyprland window manager ─────────────────────────────────────────────────
  # Config is hyprland.lua (native Lua config, requires the hyprland flake
  # input — nixpkgs' pinned version predates Lua support). Hyprland loads
  # hyprland.lua INSTEAD of hyprland.conf when it exists, so no extraConfig.
  wayland.windowManager.hyprland = {
    enable         = true;
    systemd.enable = true;
    # Silences the "no settings/extraConfig" warning — intentional, see above.
    extraConfig    = "# config lives in hyprland.lua, not here";
  };

  # ── Symlink config tree into ~/.config/hypr/ ────────────────────────────────
  xdg.configFile = {
    # Top-level conf files — force = true overwrites leftovers from old HM generation
    "hypr/hyprlock.conf" = { source = ../hypr/hyprlock.conf; force = true; };
    "hypr/hypridle.conf" = { source = ../hypr/hypridle.conf; force = true; };

    # hyprland.lua — entry point; requires("lua.<module>") resolves relative to it
    "hypr/hyprland.lua".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/hyprland.lua";

    # lua/ — the actual config modules (keybinds, monitors, startup, etc.)
    "hypr/lua".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/lua";

    # animations/ — selectable animation presets
    "hypr/animations".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/animations";

    # top-level state/meta files referenced by lua/monitors.lua + setup scripts
    "hypr/monitors.conf".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/monitors.conf";
    "hypr/workspaces.conf".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/workspaces.conf";
    "hypr/hypr-setup.sh".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/hypr-setup.sh";
    "hypr/sync.sh".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/sync.sh";
    "hypr/pkglist.txt".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/pkglist.txt";
    "hypr/aurlist.txt".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/hypr/aurlist.txt";

    # configs/ — mostly dead weight left over from the pre-Lua config (kept
    # for parity with what's still on Arch), but user-defaults.sh and
    # wallpaper_effects/ are still live-read by the Lua config/scripts.
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
