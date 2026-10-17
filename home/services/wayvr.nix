{ pkgs, ... }:

# WayVR: the desktop as screens in the headset (transport: system/services/vr.nix).
# The nixpkgs build is already patchelf'd; guides' `steam-run wayvr` is unneeded.
{
  home.packages = [ pkgs.wayvr ];

  # Not started at login: it needs a live OpenXR session, so it would crash-loop.
  # Start manually with `systemctl --user start wayvr`.
  systemd.user.services.wayvr = {
    Unit = {
      Description = "WayVR — Wayland/X11 desktop screens inside VR";
      PartOf      = [ "graphical-session.target" ];
      After       = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart  = "${pkgs.wayvr}/bin/wayvr";
      Restart    = "on-failure";
      RestartSec = 5;
    };
  };

  # Extra VR screens: `hyprctl output create headless` at runtime. Not declared,
  # since nwg-displays owns monitors.lua and would clobber them.
}
