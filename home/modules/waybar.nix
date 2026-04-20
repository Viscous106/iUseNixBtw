{ config, pkgs, ... }:

{
  # ── Waybar ──────────────────────────────────────────────────────────────────
  # Install waybar as a plain package — Startup_Apps.conf launches it via
  # `exec-once = waybar &`. This avoids the programs.waybar module generating
  # a conflicting style.css when we supply our own via xdg.configFile.
  home.packages = [ pkgs.waybar ];

  # ── Symlink Arch waybar config tree into ~/.config/waybar/ ──────────────────
  # All paths use mkOutOfStoreSymlink so files stay live-editable.
  xdg.configFile = {
    "waybar/Modules"           = { source = ../waybar/Modules;           force = true; };
    "waybar/ModulesCustom"     = { source = ../waybar/ModulesCustom;     force = true; };
    "waybar/ModulesGroups"     = { source = ../waybar/ModulesGroups;     force = true; };
    "waybar/ModulesVertical"   = { source = ../waybar/ModulesVertical;   force = true; };
    "waybar/ModulesWorkspaces" = { source = ../waybar/ModulesWorkspaces; force = true; };
    "waybar/UserModules"       = { source = ../waybar/UserModules;       force = true; };

    "waybar/configs".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/waybar/configs";
    "waybar/style".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/waybar/style";

    # Active layout and style — mirrors what WaybarLayout.sh sets on Arch
    "waybar/config".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/waybar/configs/[TOP] Default Laptop";
    "waybar/style.css".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/waybar/style/[Catppuccin] Mocha.css";
  };
}
