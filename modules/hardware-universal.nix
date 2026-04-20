{ config, pkgs, lib, ... }:

{
  # ── Kernel ────────────────────────────────────────────────────────────────
  boot.kernelPackages = pkgs.linuxPackages;   # LTS — stable + smaller initrd than latest

  # Load USB + storage modules first — critical for a USB-booted system
  boot.initrd.availableKernelModules = [
    "xhci_pci" "xhci_hcd"
    "ehci_pci" "ehci_hcd"
    "ohci_pci"
    "usb_storage" "uas"
    "sd_mod" "sr_mod"
    "nvme" "ahci" "ata_piix"
    "vmw_vmci" "vboxguest"
    "btrfs"
  ];

  # GPU modules loaded after root is mounted — NOT in initrd (keeps initrd small)
  boot.kernelModules = [
    "i915"
    "amdgpu"
    "radeon"
    "nouveau"
    "virtio_gpu"
  ];

  # ── Firmware ──────────────────────────────────────────────────────────────
  # enableRedistributableFirmware covers Intel/AMD/WiFi/GPU — plenty for portable use.
  # enableAllFirmware was removed: it dumps the full ~1GB linux-firmware into the initrd.
  hardware.enableRedistributableFirmware = true;

  # ── Graphics — generic modesetting works with all open-source GPU drivers ─
  services.xserver.videoDrivers = [ "modesetting" "fbdev" ];

  # ── Network ───────────────────────────────────────────────────────────────
  networking.useDHCP             = lib.mkDefault true;
  networking.networkmanager.enable = true;

  # ── Sound (PipeWire) ──────────────────────────────────────────────────────
  security.rtkit.enable = true;
  services.pipewire = {
    enable       = true;
    alsa.enable  = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable  = true;
  };

  # ── Power & Thermals ──────────────────────────────────────────────────────
  services.thermald.enable     = true;
  powerManagement.enable       = true;
  services.tlp.enable          = true;

  # ── zram swap (no swapfile on compressed BTRFS) ───────────────────────────
  zramSwap.enable        = true;
  zramSwap.algorithm     = "zstd";
  zramSwap.memoryPercent = 50;
}
