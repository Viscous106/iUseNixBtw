{ config, pkgs, ... }:

{
  # ── Hypridle + Hyprlock are now configured in modules/hyprland.nix ──────────
  # This module is intentionally empty so that the import in viscous.nix
  # continues to work without change.
  #
  # • services.hypridle  — enabled in hyprland.nix, config via
  #                        ~/.config/hypr/hypridle.conf (xdg.configFile)
  # • programs.hyprlock  — enabled in hyprland.nix, config via
  #                        ~/.config/hypr/hyprlock.conf (xdg.configFile)
}
