{ config, pkgs, ... }:

{
  # ── Yazi ──────────────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/yazi/ without rebuilding
  xdg.configFile."yazi".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/yazi";

  home.packages = [ pkgs.yazi ];
}
