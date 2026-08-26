{ config, pkgs, ... }:

{
  # ── Cava audio visualizer ────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/cava/ without rebuilding
  xdg.configFile."cava".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/cava";

  home.packages = [ pkgs.cava ];
}
