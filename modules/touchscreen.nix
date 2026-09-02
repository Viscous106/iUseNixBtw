{ config, lib, pkgs, ... }:

# ── Convertible / touch hardware ──────────────────────────────────────────
# Two things live here: the I2C touchscreen probe workaround (below) and the
# accelerometer plumbing that lua/laptops.lua + scripts/auto-rotate.sh use for
# tablet-mode auto-rotation.
#
# ── I2C touchscreen first-probe workaround ────────────────────────────────
# On this Chromebook (Google "Ampton", Octopus / Gemini Lake) the panel is an
# Elan controller at I2C address 0x10 on i2c-7, described in ACPI as
# \_SB.PCI0.I2C7.D010 (_HID "ELAN0001", driver elants_i2c).
#
# Its *very first* power-on at boot never runs the ACPI power resource's
# reset sequence, so the controller is still held in reset when elants_i2c
# talks to it and the probe dies with a NAK:
#
#   elants_i2c i2c-ELAN0001:00: supply vcc33 not found, using dummy regulator
#   elants_i2c i2c-ELAN0001:00: nothing at this address
#
# The driver then gives up permanently and no input device is ever created,
# which is why the touchscreen looked "unsupported". Nothing was actually
# missing from the kernel, the driver set, or libinput — the driver just lost
# the race once and never retried.
#
# Any *later* bind goes through a full PRIC._OFF/_ON cycle, which does release
# reset, and the panel enumerates every time — verified both warm and from a
# fully discharged rail (45 s powered off). So the fix is simply to re-trigger
# the bind once the system is up.
#
# Firmware also advertises two panels this unit never shipped with —
# GTCH7502 @ 0x40 (G2Touch) and WCOM50C1 @ 0x09 (Wacom digitizer), both tagged
# "linux,probed" so the OS is expected to probe and discard them. They are
# deliberately NOT retried here: they can never bind on this board, and doing
# so only adds seconds of boot delay and kernel log spam. To adapt this to a
# sibling Octopus Chromebook, add "GTCH7502:00 i2c_hid_acpi" or
# "WCOM50C1:00 i2c_hid_acpi" to the list below.
#
# Portable-safe: the entry is skipped unless the ACPI device actually exists,
# so this is a no-op on non-Chromebook hardware.
{
  # ── Accelerometer / auto-rotation ────────────────────────────────────────
  # iio-sensor-proxy exposes the panel's orientation on D-Bus. This board has
  # two accelerometers (cros-ec-accel x2) plus a gyro; the proxy picks the right
  # one on its own because the kernel labels them "accel-display" and
  # "accel-base" — the display one is what rotation must follow.
  #
  # The rotation logic itself is NOT here: it has to run inside the Hyprland
  # session (it drives hyprctl), so it lives in home/hypr/scripts/auto-rotate.sh
  # and is wired up by home/hypr/lua/laptops.lua.
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
