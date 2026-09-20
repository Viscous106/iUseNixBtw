{ pkgs, inputs, ... }:

# ── VR — Quest 3 as a wireless desktop (WiVRn transport, WayVR screens) ───
# The goal here is not gaming: it is putting this Hyprland session on floating
# screens inside the headset. That splits into two independent halves, and it
# is worth keeping them straight because they fail separately:
#
#   WiVRn  — the OpenXR *runtime* and the wireless transport. It is Monado
#            with a streaming layer bolted on, so anything the Monado docs say
#            about environment variables applies here too. This is the half
#            that talks to the Quest.
#   WayVR  — an OpenXR/OpenVR *overlay* that renders Wayland/X11 surfaces as
#            panels in 3D. This is the half that draws your desktop, and it
#            lives in home/modules/wayvr.nix because it is a user session app.
#
# Both the NixOS wiki and the Linux VR Adventures wiki converge on
# services.wivrn for standalone headsets, and both explicitly warn *against*
# Envision on NixOS (it fights the declarative Monado/WiVRn setup and breaks on
# update), which is why there is no programs.envision here.
#
# The usual NVIDIA prerequisites for this stack — modesetting, the open kernel
# modules, hardware.graphics with enable32Bit — are already satisfied by
# modules/hardware-nvidia.nix and modules/hardware-universal.nix, so nothing
# GPU-side needs adding beyond the cudaSupport override below.
let
  # allowUnfree must be set explicitly: this is a fresh nixpkgs import, so it
  # does not inherit the nixpkgs.config from configuration.nix, and the
  # cudaSupport build below pulls in unfree CUDA.
  pkgsWivrn = import inputs.nixpkgs-wivrn {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  services.wivrn = {
    enable       = true;
    openFirewall = true;   # WiVRn's discovery + stream ports on wlan0

    # No defaultRuntime here: the option was removed from nixpkgs because
    # WiVRn now registers itself as the active OpenXR runtime unconditionally.
    # Setting it is a hard assertion failure, not a warning.

    # The server is a cheap idle daemon; having it up means putting the headset
    # on and opening the WiVRn app is the entire "connect" ritual, with no
    # terminal step on the host first.
    autoStart = true;

    # Grants the compositor the priority capability it needs to hold frame
    # pacing under load. Note this is *not* the SteamVR async-reprojection path
    # that is documented as permanently broken on NVIDIA — that limitation is
    # SteamVR's, and WiVRn/Monado does its own reprojection.
    highPriority = true;

    # Two overrides stacked here, for two unrelated reasons.
    #
    # cudaSupport: without it the server falls back to CPU encoding and the
    # stream is unusable. This machine has NVENC (libnvidia-encode.so.595 in
    # /run/opengl-driver/lib), so build against it. Confirmed the override is
    # real work and not a no-op — it produces a different store path than the
    # default wivrn.
    #
    # The package comes from the separate nixpkgs-wivrn input rather than pkgs
    # because the version must match the headset client, which is a Meta Store
    # app we do not control. See the long note on that input in flake.nix.
    # Symptom when these drift: the headset says "incompatible server version"
    # and refuses to connect, with nothing wrong on the host at all.
    package = pkgsWivrn.wivrn.override { cudaSupport = true; };
  };

  # The Quest needs the WiVRn client APK, which is not on the Meta store. The
  # WiVRn dashboard can push it itself ("Install the app"), shelling out to adb.
  #
  # This used to need programs.adb.enable for udev rules + the adbusers group.
  # That option is gone from nixpkgs: systemd 258 applies uaccess to Android
  # devices automatically, so the logged-in user gets the device node with no
  # rules and no group membership. All that is left is having the binary, and
  # home/modules/dev-toolchains.nix already installs android-tools for viscous
  # — so there is deliberately nothing to declare here.
  #
  # Manual fallback if the dashboard button misbehaves:
  #   adb install org.meumeu.wivrn-release.apk   (from the WiVRn-APK repo)

  # Not enabled: xrizer. It is the maintained OpenVR->OpenXR shim (nixpkgs now
  # flags opencomposite as unmaintained and points here instead), and it is what
  # you would add to run the already-installed VRChat/SteamVR titles through
  # WiVRn. Desktop-in-VR does not need it, so it stays off until it is actually
  # wanted — `xrizer` is in this channel at 0.5.
}
