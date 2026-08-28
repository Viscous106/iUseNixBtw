#!/usr/bin/env bash
# ==============================================================================
# Portable NixOS — automated installer
#
# Run this booted from a NixOS installer ISO (minimal or graphical) to turn a
# blank disk into a bootable copy of this exact system. Safe to run from
# ANY machine — hardware-configuration.nix already uses generic drivers and
# filesystem-by-label, which is the whole point of this repo.
#
# Usage:
#   git clone <this-repo-url> nixos-config && cd nixos-config
#   sudo ./setup.sh
#
# What it does:
#   1. Partitions the disk you choose (GPT: 1GiB EFI + rest as btrfs)  — DESTRUCTIVE
#   2. Creates the @, @home, @nix, @persist, @snapshots btrfs subvolumes
#   3. Mounts everything under /mnt exactly as hardware-configuration.nix expects
#   4. Copies this repo (the directory this script lives in) to /mnt/persist/nixos-config
#   5. Runs `nixos-install --flake .../nixos-config#nix`
#
# What it deliberately does NOT do (see setup.md):
#   - Restore secrets (SSH keys, GPG keys, git identity, API keys) — those
#     never lived in git and must be copied back onto /persist/secrets by hand.
#   - Set the user's login password — set it after first boot with `passwd`.
# ==============================================================================
set -euo pipefail

# ── Sanity checks ────────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root (sudo ./setup.sh) — it partitions disks and calls nixos-install." >&2
  exit 1
fi

if ! command -v nixos-install >/dev/null 2>&1; then
  echo "nixos-install not found. This script is meant to run from a NixOS installer" >&2
  echo "environment (boot the official NixOS ISO), not from an already-installed system." >&2
  exit 1
fi

if ! ping -c1 -W3 cache.nixos.org >/dev/null 2>&1; then
  echo "No network reachable. The install needs to fetch flake inputs (nixpkgs," >&2
  echo "home-manager, Hyprland, ...) — connect to the internet first." >&2
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "$REPO_DIR doesn't look like a git checkout (no .git/) — nix flakes only see" >&2
  echo "git-tracked files, so a plain folder copy without .git won't evaluate." >&2
  exit 1
fi

echo "── Portable NixOS installer ─────────────────────────────────────────────"
echo "Repo:  $REPO_DIR"
echo

# ── Disk selection ───────────────────────────────────────────────────────────
if [ "${SKIP_PARTITION:-0}" = "1" ]; then
  echo "SKIP_PARTITION=1 set — assuming /mnt is already partitioned and mounted"
  echo "the way hardware-configuration.nix expects. Skipping to the copy+install step."
  echo
else
  echo "Block devices on this machine:"
  lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E 'disk$|NAME'
  echo
  read -rp "Target disk to WIPE and install onto (e.g. sda, nvme0n1): " DISK_NAME
  DISK="/dev/$DISK_NAME"

  if [ ! -b "$DISK" ]; then
    echo "$DISK is not a block device." >&2
    exit 1
  fi

  echo
  echo "!! EVERYTHING on $DISK will be permanently erased !!"
  lsblk "$DISK"
  echo
  read -rp "Type the disk path exactly ($DISK) to confirm: " CONFIRM
  if [ "$CONFIRM" != "$DISK" ]; then
    echo "Confirmation didn't match — aborting, nothing was touched." >&2
    exit 1
  fi

  echo
  echo "── Partitioning $DISK ────────────────────────────────────────────────"
  wipefs -a "$DISK"
  sgdisk --zap-all "$DISK"
  sgdisk --new=1:0:+1GiB   --typecode=1:ef00 --change-name=1:EFI   "$DISK"
  sgdisk --new=2:0:0       --typecode=2:8300 --change-name=2:NIXOS "$DISK"
  partprobe "$DISK"
  sleep 2

  # Handle both /dev/sdXN and /dev/nvme0n1pN naming
  if [[ "$DISK" == *nvme* ]]; then
    EFI_PART="${DISK}p1"; NIXOS_PART="${DISK}p2"
  else
    EFI_PART="${DISK}1";  NIXOS_PART="${DISK}2"
  fi

  echo "── Formatting ────────────────────────────────────────────────────────"
  mkfs.fat -F32 -n EFI "$EFI_PART"
  mkfs.btrfs -f -L NIXOS "$NIXOS_PART"

  echo "── Creating btrfs subvolumes ─────────────────────────────────────────"
  mount "$NIXOS_PART" /mnt
  for subvol in @ @home @nix @persist @snapshots; do
    btrfs subvolume create "/mnt/$subvol"
  done
  umount /mnt

  echo "── Mounting (matches hardware-configuration.nix exactly) ────────────"
  BTRFS_OPTS="noatime,compress=zstd:3,space_cache=v2,discard=async"
  mount -o "subvol=@,${BTRFS_OPTS},autodefrag"    "$NIXOS_PART" /mnt
  mkdir -p /mnt/{home,nix,persist,.snapshots,boot}
  mount -o "subvol=@home,${BTRFS_OPTS},autodefrag" "$NIXOS_PART" /mnt/home
  mount -o "subvol=@nix,${BTRFS_OPTS}"              "$NIXOS_PART" /mnt/nix
  mount -o "subvol=@persist,${BTRFS_OPTS}"          "$NIXOS_PART" /mnt/persist
  mount -o "subvol=@snapshots,${BTRFS_OPTS}"        "$NIXOS_PART" /mnt/.snapshots
  mount -o fmask=0022,dmask=0022                    "$EFI_PART"  /mnt/boot
fi

# ── Copy the repo into place ─────────────────────────────────────────────────
echo "── Copying repo to /mnt/persist/nixos-config ─────────────────────────"
mkdir -p /mnt/persist/nixos-config
cp -a "$REPO_DIR"/. /mnt/persist/nixos-config/
rm -rf /mnt/persist/nixos-config/result  # stale build symlink, if present

# Empty secrets scaffold — home-manager's activation script also does this on
# first login, but creating it now avoids a warning during the first build.
mkdir -p /mnt/persist/secrets/ssh
chmod 700 /mnt/persist/secrets/ssh

echo
echo "── Installing ─────────────────────────────────────────────────────────"
echo "This fetches nixpkgs/home-manager/Hyprland and builds the system —"
echo "expect a long wait, especially for Hyprland (built from its own flake,"
echo "not nixpkgs, so no guaranteed binary cache — see setup.md)."
echo
nixos-install --root /mnt --flake /mnt/persist/nixos-config#nix --no-root-passwd

echo
echo "── Done ────────────────────────────────────────────────────────────────"
echo "Reboot, then:"
echo "  1. Log in as viscous (password is already set from configuration.nix's hash)"
echo "  2. Restore /persist/secrets/{ssh/,git-identity,claude_api} from your own"
echo "     backup — these were never in git and won't exist yet. See setup.md."
echo "  3. Run 'passwd' if you want to change the login password."
