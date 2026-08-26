{ config, pkgs, ... }:

{
  # ── GTK 3 bookmarks ──────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/gtk-3.0/ without rebuilding
  xdg.configFile."gtk-3.0".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/gtk-3.0";
}
