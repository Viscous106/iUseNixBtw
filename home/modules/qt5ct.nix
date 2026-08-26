{ config, pkgs, ... }:

{
  # ── qt5ct ─────────────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/qt5ct/ without rebuilding
  xdg.configFile."qt5ct".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/qt5ct";

  home.packages = [ pkgs.libsForQt5.qt5ct ];
}
