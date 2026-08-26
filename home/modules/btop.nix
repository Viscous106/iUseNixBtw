{ config, pkgs, ... }:

{
  # ── Btop ──────────────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/btop/ without rebuilding
  xdg.configFile."btop".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/btop";
}
