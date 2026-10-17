{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  networking.hostName = "nix";

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.grub = {
    enable                = true;
    efiSupport            = true;
    efiInstallAsRemovable = true;   # writes to /EFI/BOOT/BOOTX64.EFI — works on any machine
    device                = "nodev";
    useOSProber           = false;
    copyKernels           = false;   # read kernel+initrd from BTRFS, not ESP
    configurationLimit    = 3;      # keep ESP usage low (1 GiB partition)
  };

  boot.loader.efi = {
    canTouchEfiVariables = false;   # NEVER write to host NVRAM
    efiSysMountPoint     = "/boot";
  };

  # ── Filesystems (by label — survives across machines) ─────────────────────
  fileSystems."/" = {
    device  = "/dev/disk/by-label/NIXOS";
    fsType  = "btrfs";
    options = [ "subvol=@" "noatime" "compress=zstd:3" "space_cache=v2" "discard=async" "autodefrag" ];
  };

  fileSystems."/home" = {
    device  = "/dev/disk/by-label/NIXOS";
    fsType  = "btrfs";
    options = [ "subvol=@home" "noatime" "compress=zstd:3" "space_cache=v2" "discard=async" "autodefrag" ];
  };

  fileSystems."/nix" = {
    device  = "/dev/disk/by-label/NIXOS";
    fsType  = "btrfs";
    # no autodefrag on /nix — Nix store objects are write-once
    options = [ "subvol=@nix" "noatime" "compress=zstd:3" "space_cache=v2" "discard=async" ];
  };

  fileSystems."/.snapshots" = {
    device  = "/dev/disk/by-label/NIXOS";
    fsType  = "btrfs";
    options = [ "subvol=@snapshots" "noatime" "compress=zstd:3" "space_cache=v2" ];
  };

  fileSystems."/persist" = {
    device       = "/dev/disk/by-label/NIXOS";
    fsType       = "btrfs";
    options      = [ "subvol=@persist" "noatime" "compress=zstd:3" "space_cache=v2" ];
    neededForBoot = true;   # ensures /persist is mounted before Home Manager activation
  };

  fileSystems."/boot" = {
    device  = "/dev/disk/by-label/EFI";
    fsType  = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # Disk swap behind zram: with 3.7 GiB RAM, evaluating this flake got OOM-killed.
  # Made with `btrfs filesystem mkswapfile` (sets NOCOW).
  swapDevices = [{ device = "/swap/swapfile"; }];

  # ── CPU microcode — include both; kernel loads the right one ──────────────
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.cpu.amd.updateMicrocode   = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # ── SMART on the USB boot stick ───────────────────────────────────────────
  # The JMicron USB-NVMe bridge hangs smartd's default probe; `-d sat` works.
  # Listed per device (not globally) so autodetect still works for other drives.
  services.smartd.devices = [
    { device = "/dev/sda"; options = "-d sat -a"; }
  ];

  # ── Platform ──────────────────────────────────────────────────────────────
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
