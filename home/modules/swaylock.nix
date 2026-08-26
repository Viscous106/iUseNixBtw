{ config, pkgs, ... }:

{
  # ── Swaylock ──────────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/swaylock/ without rebuilding
  xdg.configFile."swaylock".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/swaylock";

  home.packages = [ pkgs.swaylock-effects ];
}
