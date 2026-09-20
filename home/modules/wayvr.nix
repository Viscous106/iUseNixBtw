{ pkgs, ... }:

# ── WayVR — this Hyprland desktop as floating screens inside the headset.
# The user-session half of the VR stack; the transport half is modules/vr.nix.
#
# Formerly packaged as wlx-overlay-s. nixpkgs merged wlx-overlay-s and
# wayvr-dashboard into a single `wayvr` derivation, and the old attribute is now
# a hard eval error telling you to switch — so any guide still saying
# wlx-overlay-s predates that merge.
#
# The Linux VR Adventures wiki says to launch this as `steam-run wayvr` on
# NixOS. That advice is for the upstream/AUR binary and does NOT apply to the
# nixpkgs build: this derivation runs auto-patchelf-hook, patchelfs in the
# wayland/X11/vulkan sonames at preFixup, and substitutes absolute store paths
# for its pactl and pkill calls. xwayland-satellite is already in its runtime
# closure too. Wrapping it in the Steam FHS sandbox would only hide the real
# library paths, so it is invoked directly.
{
  home.packages = [ pkgs.wayvr ];

  # Deliberately NOT WantedBy graphical-session.target. WayVR needs a live
  # OpenXR session to attach to, so at login — headset off, nothing streaming —
  # it would fail, and Restart would turn that into a boot-time crash loop.
  # Starting it is part of putting the headset on:
  #
  #   systemctl --user start wayvr     (systemctl --user stop wayvr to drop out)
  #
  # Restart=on-failure still covers a mid-session crash once a session exists.
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

  # Extra monitors to arrange in VR are a runtime concern, not a declarative
  # one. Hyprland can spawn virtual outputs on demand:
  #
  #   hyprctl output create headless        (repeat for a second/third screen)
  #   hyprctl output remove HEADLESS-2
  #
  # Kept as a note rather than baked into hyprland.nix on purpose: monitors here
  # are owned by nwg-displays, which writes home/hypr/monitors.conf and
  # monitors.lua. Declaring headless outputs behind its back would mean two
  # writers for one piece of state, and nwg-displays would clobber them on its
  # next save. Create them when you go into VR; they vanish on removal.
}
