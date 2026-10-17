{ pkgs, ... }:

{
  # ASUS ROG tools: asusd + rog-control-center, and supergfxd for GPU modes.
  # Both just idle on non-ASUS hardware.
  programs.rog-control-center.enable = true;
  services.supergfxd.enable = true;

  # OpenRGB on demand (not the always-on server); udev rules + i2c-dev let it
  # run without sudo and reach motherboard RGB headers.
  services.udev.packages = [ pkgs.openrgb ];
  boot.kernelModules     = [ "i2c-dev" ];

  # QMK keyboards: udev access for flashing, plus the CLI.
  hardware.keyboard.qmk.enable = true;

  environment.systemPackages = with pkgs; [
    openrgb
    openrgb-plugin-effects
    qmk
  ];
}
