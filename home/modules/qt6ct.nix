{ config, pkgs, ... }:

{
  # ── qt6ct ─────────────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/qt6ct/ without rebuilding
  xdg.configFile."qt6ct".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/qt6ct";
}
