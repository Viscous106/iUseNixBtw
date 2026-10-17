{ config, pkgs, lib, ... }:

# hyprwhspr: speech-to-text. Not in nixpkgs; upstream is a plain payload copy
# and manages its own Python venv via `hyprwhspr setup`.
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
  home.packages = [ hyprwhspr pkgs.wtype ];  # ydotool comes from ydotoold.nix

  systemd.user.services.hyprwhspr = {
    Unit = {
      Description = "hyprwhspr stt";
      Requires    = [ "ydotoold.service" ]; # home/services/ydotoold.nix
      Wants       = [ "pipewire.service" ];
      After       = [ "pipewire.service" "ydotoold.service" ];

      # Skip (not fail) until `hyprwhspr setup` has created the venv; without
      # it the service exits 1 and Restart loops forever.
      ConditionPathExists = "%h/.local/share/hyprwhspr/venv/bin/python";

      # Backstop against restart loops from any other failure.
      StartLimitBurst       = 5;
      StartLimitIntervalSec = 300;
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.bash}/bin/bash -lc 'for i in $(seq 1 60); do [ -n \"$WAYLAND_DISPLAY\" ] && [ -S \"\${XDG_RUNTIME_DIR}/$WAYLAND_DISPLAY\" ] && exit 0; sleep 0.25; done; exit 1'";
      ExecStart    = "${hyprwhspr}/bin/hyprwhspr";
      Restart      = "on-failure";
      RestartSec   = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
