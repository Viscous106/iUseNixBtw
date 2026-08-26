{ config, pkgs, ... }:

{
  # ── Rofi launcher ─────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/rofi/ without rebuilding
  xdg.configFile."rofi".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/rofi";

  # ── Swaync notification center ────────────────────────────────────────────
  xdg.configFile."swaync".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/swaync";

  # ── Tmux ──────────────────────────────────────────────────────────────────
  xdg.configFile."tmux".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/tmux";

  # ── keyd app.conf — per-app passthrough rules for keyd-application-mapper ─
  xdg.configFile."keyd/app.conf".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/keyd/app.conf";
}
