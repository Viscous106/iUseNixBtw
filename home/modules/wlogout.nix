{ config, pkgs, ... }:

{
  # ── Wlogout ───────────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/wlogout/ without rebuilding
  xdg.configFile."wlogout".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/wlogout";

  home.packages = [ pkgs.wlogout ];
}
