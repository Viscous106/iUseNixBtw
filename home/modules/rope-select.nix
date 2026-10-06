{ config, pkgs, ... }:

{
  # ── rope-select ─────────────────────────────────────────────────────────────
  # Animated region selector used by ScreenShot.sh and ScreenRecord.sh in place
  # of slurp. QML is symlinked out-of-store so it can be edited without a
  # rebuild — same convention as wallpaper-picker/rofi/hypr elsewhere in this
  # repo. Only the wrapper and its dependency closure come from the store.
  xdg.configFile."quickshell/rope-select".source =
    config.lib.file.mkOutOfStoreSymlink
      "/persist/nixos-config/home/quickshell/rope-select";

  home.packages = [ pkgs.rope-select ];
}
