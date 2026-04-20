{ config, pkgs, lib, ... }:

{
  # ── Waybar status bar ────────────────────────────────────────────────────────
  # Package + systemd service managed by Home Manager.
  # All config files are the exact Arch configs symlinked via xdg.configFile.
  programs.waybar = {
    enable         = true;
    systemd.enable = true;
    # Prevent Home Manager from generating any settings or style.
    settings = [];
    style    = "";
  };

  # ── Symlink Arch waybar config tree into ~/.config/waybar/ ──────────────────
  xdg.configFile = {
    # Module definition files
    "waybar/Modules"           = { source = ../waybar/Modules;           force = true; };
    "waybar/ModulesCustom"     = { source = ../waybar/ModulesCustom;     force = true; };
    "waybar/ModulesGroups"     = { source = ../waybar/ModulesGroups;     force = true; };
    "waybar/ModulesVertical"   = { source = ../waybar/ModulesVertical;   force = true; };
    "waybar/ModulesWorkspaces" = { source = ../waybar/ModulesWorkspaces; force = true; };
    "waybar/UserModules"       = { source = ../waybar/UserModules;       force = true; };

    # All layout configs and styles — live-editable directories
    "waybar/configs".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/waybar/configs";
    "waybar/style".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/waybar/style";

    # Active layout: [TOP] Default Laptop  (change to switch layout)
    "waybar/config".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/waybar/configs/[TOP] Default Laptop";

    # Active style: Catppuccin Mocha  (change to switch theme)
    "waybar/style.css".source = config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/waybar/style/[Catppuccin] Mocha.css";
  };
}
