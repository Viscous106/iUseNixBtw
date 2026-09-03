{ config, lib, pkgs, modulesPath, ... }:

# ══════════════════════════════════════════════════════════════════════════════
# Internal NVMe install — encrypted, machine-specific.
#
# This is the counterpart to hardware-configuration.nix, NOT a replacement.
# That file stays exactly as it is: it describes the portable USB drive
# (by-label, generic drivers, GRUB-as-removable, never touches NVRAM).
#
# This file describes the opposite situation — one fixed laptop, one internal
# disk, LUKS2 on top of it — so the portability tricks are deliberately dropped:
#
#   by-label   → /dev/mapper/cryptroot and by-partlabel. With the USB enclosure
#                plugged in, two filesystems answering to the same label is a
#                coin flip; the mapper name is ours and can't be ambiguous.
#                Nothing here needs a UUID, so the file is machine-independent
#                text that install-nvme-encrypted.sh never has to rewrite.
#   GRUB       → systemd-boot. Removable-media GRUB exists to make the USB boot
#                anywhere; this disk never leaves the machine, and lanzaboote
#                (Secure Boot, later) builds on systemd-boot.
#   NVRAM off  → NVRAM on. Writing boot entries is correct on your own machine.
# ══════════════════════════════════════════════════════════════════════════════

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Distinct host so `nixos-rebuild switch --flake /persist/nixos-config` picks
  # nixosConfigurations.laptop by hostname, with no #target to remember.
  # configuration.nix sets "nix" for the portable install, hence mkForce.
  networking.hostName = lib.mkForce "laptop";

  # ── Boot ────────────────────────────────────────────────────────────────────
  boot.loader.systemd-boot = {
    enable             = true;
    configurationLimit = 10;   # ESP is 1 GiB and kernels live on btrfs, not here
    editor             = false; # no cmdline editing at the menu ⇒ no init=/bin/sh
  };

  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint     = "/boot";
  };

  # systemd in the initrd: a sane LUKS prompt now, and the prerequisite for
  # systemd-cryptenroll / TPM2 unlocking later.
  boot.initrd.systemd.enable = true;

  # ── Disk encryption ─────────────────────────────────────────────────────────
  boot.initrd.luks.devices."cryptroot" = {
    # GPT partition name set by install-nvme-encrypted.sh. Not by-uuid, so this
    # file needs no per-install edit; not by-label, because a LUKS label and the
    # inner filesystem label can both surface under /dev/disk/by-label.
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

  # Swap in its own subvolume: a swapfile inside @ would block snapshotting @,
  # which is why the USB install's @/swap/swapfile is worth not repeating here.
  # No compression — a compressed swapfile is not usable as swap.
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

  # Created with `btrfs filesystem mkswapfile` (sets NOCOW, which plain
  # fallocate does not). zram from hardware-universal.nix still applies; this
  # backs it, same reasoning as the portable profile.
  swapDevices = [{ device = "/swap/swapfile"; }];

  # ── Platform ────────────────────────────────────────────────────────────────
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
