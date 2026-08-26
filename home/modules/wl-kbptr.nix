{ config, pkgs, ... }:

{
  # ── wl-kbptr ──────────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/wl-kbptr/ without rebuilding
  xdg.configFile."wl-kbptr".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/wl-kbptr";
}
