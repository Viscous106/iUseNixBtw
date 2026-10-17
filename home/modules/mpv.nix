{ config, pkgs, ... }:

let
  repo = "/persist/nixos-config/home/mpv";
in
{
  # ── Mpv ───────────────────────────────────────────────────────────────────
  # Configs are live-editable symlinks; the MPRIS plugin comes from nixpkgs.
  xdg.configFile = {
    "mpv/mpv.conf".source   = config.lib.file.mkOutOfStoreSymlink "${repo}/mpv.conf";
    "mpv/input.conf".source = config.lib.file.mkOutOfStoreSymlink "${repo}/input.conf";
    "mpv/scripts/mpris.so".source = "${pkgs.mpvScripts.mpris}/share/mpv/scripts/mpris.so";
  };
}
