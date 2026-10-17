{ pkgs, ... }:

{
  programs.kdeconnect.enable = true;  # also opens ports 1714-1764

  # Udev hotplug rules left off (upstream bug #140); plug devices in before
  # the service starts, or re-attach them.
  services.input-remapper.enable = true;
  environment.systemPackages = [ pkgs.input-remapper ];

  services.earlyoom.enable = true;
  # Autodetects drives. Don't list devices here: a missing one is fatal, and
  # this file applies to both hosts (the USB stick's entry is in hosts/usb.nix).
  services.smartd.enable = true;
}
