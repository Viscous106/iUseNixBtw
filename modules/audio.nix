{ config, lib, pkgs, ... }:

# ── Audio for this machine: ASUS TUF Gaming A15 (FA507NUR) ──────────────────
#
# Hardware actually present (see /proc/asound/cards, lspci):
#   card 0  NVIDIA AD107 HDMI/DP audio           01:00.1
#   card 1  AMD Ryzen HD Audio + Realtek ALC256  05:00.6  ← speakers, jack, internal mic
#           AMD ACP6x "Audio Coprocessor"        05:00.5  ← no card, see note at the bottom
#
# This file replaces modules/audio-glkrt5682max.nix, which shipped an ALSA UCM
# profile for a Google Ampton Chromebook (Gemini Lake + RT5682). That board does
# not exist on this laptop — nothing here ever loaded it, and it forced
# ALSA_CONFIG_UCM2 system-wide at a snapshot of alsa-ucm-conf for no benefit.
#
# ── The microphone bug this fixes ───────────────────────────────────────────
# The internal mic is an analog pin on the ALC256 (node 0x12, "Mic at Int"), and
# PipeWire's ACP layer builds its 0-100% volume range by stacking TWO hardware
# gain stages from analog-input-internal-mic.conf:
#
#     [Element Capture]              0..63  →  -17.25 .. +30.00 dB
#     [Element Internal Mic Boost]   0..3   →    0.00 .. +30.00 dB   (volume = merge)
#
# So PipeWire at 100% drives +60 dB into an internal mic. Measured: 90% of
# samples pinned to ±32768 — a hard-railed square wave, not speech. Anything
# above ~40% clips. Pressing the mic-volume-up key walks straight into it,
# because it is the top of the ordinary volume range.
#
# ACP reads its mixer paths from $ACP_PATHS_DIR when set, so we hand it a copy
# of the upstream tree with the boost stage taken out of the volume range
# (volume = off). The boost element still exists for the driver; it just stops
# being part of what the volume slider moves. After this, 100% = +30 dB, which
# measures -4.7 dBFS peak — loud, clean, no clipping anywhere on the dial.
#
# Same reasoning as the old UCM module for using an env var rather than an
# overlay: overriding pkgs.pipewire rebuilds it and everything downstream.
# Pointing ACP at a store path built with runCommand costs one tiny derivation.

let
  acpPaths = pkgs.runCommand "acp-mixer-paths-alc256" { } ''
    mkdir -p $out
    cp ${config.services.pipewire.package}/share/alsa-card-profile/mixer/paths/*.conf $out/
    chmod u+w $out/*.conf

    # Take "Internal Mic Boost" out of the merged volume range. Section-scoped:
    # `volume = merge` appears under several elements in these files.
    for f in analog-input-internal-mic.conf analog-input-internal-mic-always.conf; do
      awk '
        /^\[/ { sect = $0 }
        sect == "[Element Internal Mic Boost]" && $0 ~ /^volume[[:space:]]*=[[:space:]]*merge$/ {
          print "volume = off"; found = 1; next
        }
        { print }
        END {
          if (!found) {
            print "ERROR: no [Element Internal Mic Boost] volume=merge in " FILENAME > "/dev/stderr"
            exit 1
          }
        }
      ' $out/$f > $out/$f.new
      mv $out/$f.new $out/$f
    done

    # Fail the build rather than silently shipping an unpatched tree.
    grep -q '^volume = off' $out/analog-input-internal-mic.conf
  '';
in
{
  # ACP lives in the pipewire daemon; wireplumber drives it. systemd user units
  # do not reliably inherit session variables, so set it on the units directly.
  environment.sessionVariables.ACP_PATHS_DIR = "${acpPaths}";
  systemd.user.services.pipewire.environment.ACP_PATHS_DIR       = "${acpPaths}";
  systemd.user.services.pipewire-pulse.environment.ACP_PATHS_DIR = "${acpPaths}";
  systemd.user.services.wireplumber.environment.ACP_PATHS_DIR    = "${acpPaths}";

  # ── Bluetooth headset microphone (HFP) ────────────────────────────────────
  # The earbuds connected A2DP-only: `Active Profile: a2dp-sink`, which reports
  # `sources: 0` — playback, no mic. Every attempt to bring up the mic side
  # failed in bluetoothd:
  #   src/profile.c:ext_confirm() Hands-Free Voice gateway authorization failure
  #   src/profile.c:record_cb()   Unable to get Hands-Free Voice gateway SDP record
  # bluetoothd was not advertising the Hands-Free Audio Gateway profile, because
  # its default plugin set does not enable it and nothing here asked for it.
  # Enable spells out the profiles bluetoothd registers.
  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
      # Battery level reporting for headsets, and the newer LE features BlueZ
      # keeps behind this flag.
      Experimental = true;
      # Re-pair silently instead of erroring when a "Just Works" device (most
      # cheap earbuds) comes back with different keys.
      JustWorksRepairing = "always";
    };
    Policy.AutoEnable = true;
  };

  services.pipewire.wireplumber.extraConfig = {
    # Advertise the HFP/HSP roles and let WirePlumber drop out of A2DP into
    # HFP on its own when an application opens the headset's microphone —
    # which is exactly what a Meet/Zoom tab does.
    "10-bluez-headset" = {
      "monitor.bluez.properties" = {
        "bluez5.roles"              = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" "a2dp_sink" "a2dp_source" ];
        "bluez5.autoswitch-profile" = true;
        "bluez5.enable-msbc"        = true;   # wideband speech, far better than CVSD
        "bluez5.enable-sbc-xq"      = true;
        "bluez5.enable-hw-volume"   = true;
      };
    };

    # ── Keep the internal mic the fallback microphone ───────────────────────
    # WirePlumber had no `default.configured.audio.source` at all, so the
    # default source floated to whatever appeared last — in practice the
    # bluez_input filter node of earbuds sitting in A2DP, i.e. a "microphone"
    # with no capture stream behind it. Raising the built-in mic's session
    # priority makes it the one that wins whenever nothing better is present.
    "51-internal-mic-priority" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "alsa_input.pci-0000_05_00.6.analog-stereo"; } ];
          actions.update-props = { "priority.session" = 2000; };
        }
      ];
    };
  };

  # ── Not a bug: the AMD ACP6x has no card ──────────────────────────────────
  # snd_pci_acp6x binds 05:00.5 and speculatively creates the acp_yc_mach.0
  # platform device, but snd_soc_acp6x_mach declines to bind it (this model is
  # not in the kernel's yc_acp_quirk_table). That is correct here: the DMIC path
  # it would drive is unused on this board — the microphone is the ALC256 analog
  # pin above. Nothing to fix; noted so the unbound device is not chased again.
}
