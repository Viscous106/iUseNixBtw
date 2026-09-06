{ config, pkgs, ... }:

{
  # ── Wallpaper picker ────────────────────────────────────────────────────────
  # QML is symlinked out-of-store so it can be edited without a rebuild — same
  # convention as rofi/qt6ct/hypr elsewhere in this repo. Only the wrapper and
  # its dependency closure come from the store.
  xdg.configFile."quickshell/wallpaper-picker".source =
    config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/quickshell/wallpaper-picker";

  home.packages = [ pkgs.wallpaper-picker ];
}
