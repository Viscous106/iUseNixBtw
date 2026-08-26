{ config, pkgs, ... }:

{
  # ── thefuck ───────────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/thefuck/ without rebuilding
  xdg.configFile."thefuck".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/thefuck";

  home.packages = [ pkgs.thefuck ];
}
