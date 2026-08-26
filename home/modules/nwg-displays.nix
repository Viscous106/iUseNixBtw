{ config, pkgs, ... }:

{
  # ── nwg-displays ─────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/nwg-displays/ without rebuilding
  xdg.configFile."nwg-displays".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/nwg-displays";

  home.packages = [ pkgs.nwg-displays ];
}
