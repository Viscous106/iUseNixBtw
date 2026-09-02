{ config, pkgs, lib, ... }:

# ── hyprwhspr — system-wide speech-to-text, ported from an AUR-git package ──
# Not in nixpkgs. Arch's own AUR PKGBUILD doesn't compile anything either —
# it's a payload copy (bin/lib/config/share) of github:goodroot/hyprwhspr
# plus a systemd user service; the app manages its own Python venv via
# `hyprwhspr setup` (pip-installs into ~/.local/share/hyprwhspr/venv) rather
# than shipping pinned deps, so that's reproduced here rather than worked
# around — this matches how the tool is installed everywhere, not just Arch.
#
# On the live Arch box, ~/.config/hyprwhspr/config.json has
# transcription_backend "nvidia" with an empty rest_endpoint_url/rest_api_key
# — i.e. transcription isn't actually wired up to anything there either, so
# this port doesn't functionally regress anything.
let
  hyprwhspr = pkgs.stdenv.mkDerivation {
    pname = "hyprwhspr";
    version = "unstable-2026-08";

    src = pkgs.fetchFromGitHub {
      owner = "goodroot";
      repo  = "hyprwhspr";
      rev   = "f027876a2e2f4f37e18c2d2143d155a20fdedbb6";
      hash  = "sha256-qDBxyy4pNuyGv+gUuJgQ0usyDA/PcWgLZjd4UH5Y0Q8=";
    };

    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/lib $out/share $out/config
      cp -r lib/.    $out/lib/
      cp -r share/.  $out/share/
      cp -r config/. $out/config/
      install -Dm755 bin/hyprwhspr $out/bin/hyprwhspr
      runHook postInstall
    '';

    meta.mainProgram = "hyprwhspr";
  };
in
{
  home.packages = [ hyprwhspr pkgs.ydotool pkgs.wtype ];

  # ── Config — vendored verbatim from Arch's ~/.config/hyprwhspr/config.json ─
  xdg.configFile."hyprwhspr/config.json".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/hyprwhspr/config.json";

  # ── systemd user service — matches the unit actually deployed on Arch at
  # ~/.config/systemd/user/hyprwhspr.service (Requires=ydotool.service, a
  # short wait for a Wayland socket, restart-on-failure), with ExecStart
  # pointed at the Nix store build instead of /usr/lib/hyprwhspr.
  systemd.user.services.hyprwhspr = {
    Unit = {
      Description = "hyprwhspr stt";
      # Arch's deployed unit actually said `Requires=ydotool.service`, but
      # that unit file was empty (0 bytes) there too — a dangling reference
      # to a unit that was never the real daemon. The real, enabled daemon
      # on Arch is ydotoold.service (see home/modules/ydotoold.nix); fixed
      # here rather than reproducing the dead reference.
      Requires    = [ "ydotoold.service" ];
      Wants       = [ "pipewire.service" ];
      After       = [ "pipewire.service" "ydotoold.service" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.bash}/bin/bash -lc 'for i in $(seq 1 60); do [ -n \"$WAYLAND_DISPLAY\" ] && [ -S \"\${XDG_RUNTIME_DIR}/$WAYLAND_DISPLAY\" ] && exit 0; sleep 0.25; done; exit 1'";
      ExecStart    = "${hyprwhspr}/bin/hyprwhspr";
      Restart      = "on-failure";
      RestartSec   = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
