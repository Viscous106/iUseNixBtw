{ pkgs, inputs, ... }:

# VR: Quest 3 as a wireless desktop. WiVRn is the OpenXR runtime/transport;
# the WayVR overlay lives in home/services/wayvr.nix. Envision is avoided on
# NixOS (it fights the declarative WiVRn setup).
let
  # Fresh nixpkgs import doesn't inherit nixpkgs.config; CUDA needs unfree.
  pkgsWivrn = import inputs.nixpkgs-wivrn {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  services.wivrn = {
    enable       = true;
    openFirewall = true;   # WiVRn's discovery + stream ports on wlan0

    # No defaultRuntime: removed upstream, setting it fails an assertion.

    # Cheap idle daemon; connecting is just opening the app on the headset.
    autoStart = true;

    # Compositor priority for frame pacing (WiVRn does its own reprojection).
    highPriority = true;

    # Version must match the Meta Store client (see nixpkgs-wivrn in flake.nix);
    # a mismatch shows "incompatible server version". CUDA for NVENC encoding.
    package = pkgsWivrn.wivrn.override { cudaSupport = true; };
  };

  # Client APK: push via the WiVRn dashboard ("Install the app") or
  # `adb install`; adb comes from home/dev/toolchains.nix, systemd uaccess handles perms.

  # Real-time scheduling for the VR compositor, to avoid stutter.
  security.pam.loginLimits = [
    { domain = "@users"; item = "rtprio"; type = "-"; value = 1; }
  ];
}
