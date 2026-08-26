{ config, pkgs, ... }:

{
  # ── Mpv ───────────────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/mpv/ without rebuilding
  xdg.configFile."mpv".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/mpv";
}
