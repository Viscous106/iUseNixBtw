{ config, lib, pkgs, ... }:

# ── ALSA UCM profile for sof-glkrt5682max (Google Ampton / GLK Chromebook) ──
#
# Problem this solves:
#   alsa-ucm-conf ships Intel/sof-glkda7219max (the DA7219 variant of this
#   board) but has no profile for the RT5682 variant this laptop uses. With no
#   UCM profile, PipeWire's ACP layer falls back to probing the mixer and only
#   discovers the headphone jack — producing a single "stereo-fallback" profile
#   whose one port is unavailable whenever nothing is plugged in. The card then
#   sits at profile "off" and the only sink is the dummy `auto_null`, so there
#   is no audio output at all.
#
#   Adding a proper UCM profile makes PipeWire expose real Speaker / Headphones
#   / Mic / Headset / HDMI devices with working jack detection.
#
# Why the env var instead of overriding pkgs.alsa-ucm-conf:
#   alsa-lib references alsa-ucm-conf directly, so an overlay forces a rebuild
#   of alsa-lib and ~130 downstream packages — hours on this machine. alsa-lib
#   reads ALSA_CONFIG_UCM2 for the UCM root, so we hand it a merged tree
#   (upstream + our profile) built in the store instead. Zero rebuilds.
#
# Card identification (from /proc/asound/cards):
#     0 [sofglkrt5682max]: sof-glkrt5682ma - sof-glkrt5682max
#                          Google-Ampton-rev4
#   alsa-lib probes ucm2/conf.d/${CardDriver}/${CardDriver}.conf, and CardDriver
#   is the driver field truncated to ALSA's 15-char limit: "sof-glkrt5682ma".
#   That truncated name is why the conf.d directory is spelled without the "x".

let
  ucm2 = pkgs.runCommand "alsa-ucm2-glkrt5682max" { } ''
    mkdir -p $out
    cp -r --no-preserve=mode,ownership \
      ${pkgs.alsa-ucm-conf}/share/alsa/ucm2/. $out/
    cp -r --no-preserve=mode,ownership \
      ${./ucm}/. $out/

    # Fail the build rather than silently shipping a broken profile.
    test -f $out/conf.d/sof-glkrt5682ma/sof-glkrt5682ma.conf
    test -f $out/Intel/sof-glkrt5682max/HiFi.conf
  '';
in
{
  # Regular applications and login shells.
  environment.sessionVariables.ALSA_CONFIG_UCM2 = "${ucm2}";

  # The audio stack runs as systemd user services, which do not reliably
  # inherit session variables — set it on the units explicitly.
  systemd.user.services.pipewire.environment.ALSA_CONFIG_UCM2 = "${ucm2}";
  systemd.user.services.pipewire-pulse.environment.ALSA_CONFIG_UCM2 = "${ucm2}";
  systemd.user.services.wireplumber.environment.ALSA_CONFIG_UCM2 = "${ucm2}";
}
