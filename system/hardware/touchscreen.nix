{ config, lib, pkgs, ... }:

# Convertible / touch hardware: accelerometer for auto-rotation, and a re-probe
# for an Elan I2C touchscreen (ELAN0001) whose first ACPI power-on leaves it in
# reset so elants_i2c NAKs and never retries. Skipped if the device is absent.
{
  # iio-sensor-proxy exposes orientation on D-Bus. The rotation itself runs in
  # the Hyprland session (dotfiles/hypr/scripts/auto-rotate.sh via lua/laptops.lua).
  hardware.sensor.iio.enable = true;

  environment.systemPackages = with pkgs; [
    iio-sensor-proxy   # `monitor-sensor` — the orientation event stream
    evtest             # reads SW_TABLET_MODE so a session that starts folded
                       # comes up already rotated
  ];

  systemd.services.i2c-touchscreen-rebind = {
    description = "Re-probe I2C touchscreen (first ACPI power-on leaves it in reset)";

    wantedBy = [ "multi-user.target" ];
    wants    = [ "systemd-udev-settle.service" ];
    after    = [ "systemd-udev-settle.service" ];

    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
    };

    path = [ pkgs.kmod ];

    script = ''
      # "<acpi i2c device> <driver>" pairs to retry
      for pair in "ELAN0001:00 elants_i2c"; do
        dev=''${pair%% *}
        drv=''${pair##* }

        # Not this machine's hardware — skip.
        [ -e "/sys/bus/i2c/devices/i2c-$dev" ] || continue

        modprobe "$drv" 2>/dev/null || true
        [ -d "/sys/bus/i2c/drivers/$drv" ] || continue

        # Each failed bind ends in PRIC._OFF, so the next attempt starts from a
        # clean power cycle. In practice attempt 1 succeeds.
        i=0
        while [ "$i" -lt 5 ]; do
          if [ -e "/sys/bus/i2c/devices/i2c-$dev/driver" ]; then
            echo "i2c-$dev: bound to $drv"
            exit 0
          fi
          echo "i2c-$dev" > "/sys/bus/i2c/drivers/$drv/bind" 2>/dev/null || true
          i=$((i + 1))
          sleep 1
        done
        echo "i2c-$dev: still not bound to $drv after $i attempts" >&2
      done
    '';
  };
}
