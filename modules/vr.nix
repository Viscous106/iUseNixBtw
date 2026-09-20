{ pkgs, ... }:

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
{
  services.wivrn = {
    enable       = true;
    openFirewall = true;   # WiVRn's discovery + stream ports on wlan0

    # Register WiVRn as the system OpenXR runtime (writes the active_runtime
    # json). WayVR has no way to find the compositor without this, and neither
    # would any other OpenXR client.
    defaultRuntime = true;

    # The server is a cheap idle daemon; having it up means putting the headset
    # on and opening the WiVRn app is the entire "connect" ritual, with no
    # terminal step on the host first.
    autoStart = true;

    # Grants the compositor the priority capability it needs to hold frame
    # pacing under load. Note this is *not* the SteamVR async-reprojection path
    # that is documented as permanently broken on NVIDIA — that limitation is
    # SteamVR's, and WiVRn/Monado does its own reprojection.
    highPriority = true;

    # Without cudaSupport the server falls back to CPU encoding and the stream
    # is unusable. This machine has NVENC (libnvidia-encode.so.595 is present
    # in /run/opengl-driver/lib), so build WiVRn against it. Verified that the
    # override is accepted on this channel — wivrn 26.6.2.
    package = pkgs.wivrn.override { cudaSupport = true; };
  };

  # The Quest needs the WiVRn client APK, which is not on the Meta store. The
  # WiVRn dashboard can push it itself ("Install the app"), but it shells out to
  # adb to do it — and adb cannot see the headset without the udev rules and the
  # adbusers group that this option creates. home/modules/dev-toolchains.nix
  # already puts the adb *binary* on PATH via android-tools; that is orthogonal,
  # it grants no device permissions. viscous is added to adbusers in
  # configuration.nix.
  #
  # Manual fallback if the dashboard button misbehaves:
  #   adb install org.meumeu.wivrn-release.apk   (from the WiVRn-APK repo)
  programs.adb.enable = true;

  # Not enabled: xrizer. It is the maintained OpenVR->OpenXR shim (nixpkgs now
  # flags opencomposite as unmaintained and points here instead), and it is what
  # you would add to run the already-installed VRChat/SteamVR titles through
  # WiVRn. Desktop-in-VR does not need it, so it stays off until it is actually
  # wanted — `xrizer` is in this channel at 0.5.
}
