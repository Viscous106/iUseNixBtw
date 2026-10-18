{ config, lib, pkgs, modulesPath, ... }:

# Internal NVMe install: LUKS2 + btrfs, systemd-boot. /dev/mapper and by-partlabel, not
# by-label, since the USB drive's labels would collide.

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Matches nixosConfigurations.laptop, so `nixos-rebuild --flake .` needs no #target.
  networking.hostName = "laptop";

  # ── Boot ────────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot = {
    enable             = true;
    configurationLimit = 3;    # matches the 3 generations nix.gc keeps (system/core/nix.nix)
    editor             = false; # no cmdline editing at the menu ⇒ no init=/bin/sh
  };

  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint     = "/boot";
  };

  # Better LUKS prompt; prerequisite for systemd-cryptenroll / TPM2 unlock.
  boot.initrd.systemd.enable = true;

  # ── Disk encryption ─────────────────────────────────────────────────────────
  boot.initrd.luks.devices."cryptroot" = {
    # GPT partlabel from install-nvme-encrypted.sh: no per-install UUID edit,
    # and unambiguous unlike by-label.
    device           = "/dev/disk/by-partlabel/nixcrypt";
    allowDiscards    = true;   # TRIM through LUKS: leaks free-space layout to
                               # someone imaging the disk, keeps the SSD healthy
    bypassWorkqueues = true;   # measurably lower latency on NVMe
  };

  # ── Filesystems ─────────────────────────────────────────────────────────────
  fileSystems."/" = {
    device  = "/dev/mapper/cryptroot";
    fsType  = "btrfs";
    options = [ "subvol=@" "noatime" "compress=zstd:3" "space_cache=v2" "discard=async" "autodefrag" ];
  };

  fileSystems."/home" = {
    device  = "/dev/mapper/cryptroot";
    fsType  = "btrfs";
    options = [ "subvol=@home" "noatime" "compress=zstd:3" "space_cache=v2" "discard=async" "autodefrag" ];
  };

  fileSystems."/nix" = {
    device  = "/dev/mapper/cryptroot";
    fsType  = "btrfs";
    # no autodefrag on /nix — store objects are write-once
    options = [ "subvol=@nix" "noatime" "compress=zstd:3" "space_cache=v2" "discard=async" ];
  };

  fileSystems."/persist" = {
    device        = "/dev/mapper/cryptroot";
    fsType        = "btrfs";
    options       = [ "subvol=@persist" "noatime" "compress=zstd:3" "space_cache=v2" ];
    neededForBoot = true;   # Home Manager activation reads it
  };

  fileSystems."/.snapshots" = {
    device  = "/dev/mapper/cryptroot";
    fsType  = "btrfs";
    options = [ "subvol=@snapshots" "noatime" "compress=zstd:3" "space_cache=v2" ];
  };

  # Own subvolume so a swapfile doesn't block snapshotting @. No compression:
  # a compressed swapfile can't be used as swap.
  fileSystems."/swap" = {
    device  = "/dev/mapper/cryptroot";
    fsType  = "btrfs";
    options = [ "subvol=@swap" "noatime" ];
  };

  fileSystems."/boot" = {
    device  = "/dev/disk/by-partlabel/nixesp";
    fsType  = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];   # keep the ESP out of world-read
  };

  # Disk swap behind zram; made with `btrfs filesystem mkswapfile` (sets NOCOW).
  swapDevices = [{ device = "/swap/swapfile"; }];

  # ── Platform ────────────────────────────────────────────────────────────────
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
