{ config, pkgs, ... }:

{
  # ── nwg-look ─────────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/nwg-look/ without rebuilding
  xdg.configFile."nwg-look".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/nwg-look";

  home.packages = [ pkgs.nwg-look ];
}
