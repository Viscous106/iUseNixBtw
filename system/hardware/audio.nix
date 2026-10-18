{ config, lib, pkgs, ... }:

# ASUS TUF A15 audio. Mic clipping: ACP stacks Capture + Internal Mic Boost (+30 dB each), so ACP_PATHS_DIR
# points at mixer paths without the boost (env var, not an overlay, to avoid rebuilding pipewire).

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
  # bluetoothd's default plugins skip the Hands-Free gateway, so earbuds had no mic.
  hardware.bluetooth.settings = {
    General = {
      Enable = "Source,Sink,Media,Socket";
      # Headset battery reporting and newer LE features.
      Experimental = true;
      # Re-pair silently when a "Just Works" device returns with new keys.
      JustWorksRepairing = "always";
    };
    Policy.AutoEnable = true;
  };

  services.pipewire.wireplumber.extraConfig = {
    # Auto-switch A2DP -> HFP when an app opens the headset mic.
    "10-bluez-headset" = {
      "monitor.bluez.properties" = {
        "bluez5.roles"              = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" "a2dp_sink" "a2dp_source" ];
        "bluez5.autoswitch-profile" = true;
        "bluez5.enable-msbc"        = true;   # wideband speech, far better than CVSD
        "bluez5.enable-sbc-xq"      = true;
        "bluez5.enable-hw-volume"   = true;
      };
    };

    # Make the internal mic the fallback default source, instead of an A2DP
    # earbud node with no capture stream.
    "51-internal-mic-priority" = {
      "monitor.alsa.rules" = [
        {
          matches = [ { "node.name" = "alsa_input.pci-0000_05_00.6.analog-stereo"; } ];
          actions.update-props = { "priority.session" = 2000; };
        }
      ];
    };
  };

  # The AMD ACP6x (05:00.5) creating no card is expected: the board's mic is the
  # ALC256 analog pin, not the ACP DMIC path.
}
