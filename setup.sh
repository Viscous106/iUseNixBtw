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
#   If `git` itself isn't on the ISO (some minimal variants omit it), grab it
#   from Nix first: `nix-shell -p git --run 'git clone <this-repo-url> nixos-config'`.
#   Everything setup.sh itself needs (partitioning/mkfs tools) is checked and
#   self-provided via nix-shell below — no other manual setup required.
#
# What it does:
#   1. Partitions the disk you choose (GPT: 1GiB EFI + rest as btrfs)  — DESTRUCTIVE
#   2. Creates the @, @home, @nix, @persist, @snapshots btrfs subvolumes
#   3. Mounts everything under /mnt exactly as hardware-configuration.nix expects
#   4. Copies this repo (the directory this script lives in) to /mnt/persist/nixos-config
#   5. Prompts for the login username + password and writes them into the
#      COPIED user.nix, hashed with `mkpasswd -m sha-512` — the checkout you
#      ran this from keeps its own values
#   6. Runs `nixos-install --flake .../nixos-config#nix`
#
# What it deliberately does NOT do (see setup.md):
#   - Restore secrets (SSH keys, GPG keys, git identity, API keys) — those
#     never lived in git and must be copied back onto /persist/secrets by hand.
# ==============================================================================
set -euo pipefail

# ── Sanity checks ────────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  echo "Run this as root (sudo ./setup.sh) — it partitions disks and calls nixos-install." >&2
  exit 1
fi

# ── Dependency self-heal ─────────────────────────────────────────────────────
# A first-time install can't assume anything beyond a bare NixOS ISO. If any
# tool this script (or `nixos-install --flake`, which needs git to read a
# flake's tracked files) uses isn't already on PATH, re-exec everything inside
# a nix-shell that provides it — so this works the same on a minimal ISO as
# a graphical one, without the user having to hunt down packages by hand.
# Placed after the root check (not before) so the re-exec runs as root, since
# `sudo` resets PATH and would otherwise drop a nix-shell set up beforehand.
declare -A _SETUP_CMD_TO_PKG=(
  [git]=git             [wipefs]=util-linux     [sgdisk]=gptfdisk
  [partprobe]=parted    [mkfs.fat]=dosfstools   [mkfs.btrfs]=btrfs-progs
  [btrfs]=btrfs-progs   [mount]=util-linux      [umount]=util-linux
  [ping]=iputils        [lsblk]=util-linux      [sed]=gnused
  [mkpasswd]=mkpasswd
)
_SETUP_MISSING_PKGS=()
for _cmd in "${!_SETUP_CMD_TO_PKG[@]}"; do
  command -v "$_cmd" >/dev/null 2>&1 || _SETUP_MISSING_PKGS+=("${_SETUP_CMD_TO_PKG[$_cmd]}")
done
if [ "${#_SETUP_MISSING_PKGS[@]}" -gt 0 ]; then
  if [ -n "${NIXOS_SETUP_REEXEC:-}" ]; then
    echo "Still missing after a nix-shell re-exec: ${_SETUP_MISSING_PKGS[*]} — something" >&2
    echo "is wrong with that nix-shell invocation itself; can't continue." >&2
    exit 1
  fi
  if ! command -v nix-shell >/dev/null 2>&1; then
    echo "Missing: ${_SETUP_MISSING_PKGS[*]} — and no nix-shell to fetch them with." >&2
    echo "This really doesn't look like a NixOS installer environment." >&2
    exit 1
  fi
  mapfile -t _SETUP_MISSING_PKGS < <(printf '%s\n' "${_SETUP_MISSING_PKGS[@]}" | sort -u)
  echo "Missing on this system: ${_SETUP_MISSING_PKGS[*]}"
  echo "Re-running this script inside a nix-shell that provides them ..."
  exec nix-shell -p "${_SETUP_MISSING_PKGS[@]}" \
    --run "NIXOS_SETUP_REEXEC=1 exec bash $(printf '%q' "${BASH_SOURCE[0]}") ${*@Q}"
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

# ── GPU driver selection ─────────────────────────────────────────────────────
# modules/hardware-nvidia.nix hard-forces the NVIDIA driver for this repo's
# reference machine (RTX 4050 Max-Q) — it is NOT auto-detected. Including it
# on a laptop without that exact GPU can leave Hyprland with no working
# display driver (CPU-rendered via llvmpipe at best, black screen at worst).
echo
echo "── GPU configuration ───────────────────────────────────────────────────"
echo "modules/hardware-nvidia.nix force-enables the NVIDIA driver (RTX 4050"
echo "Max-Q, this repo's reference machine). It is not auto-detected."
echo
read -rp "Does THIS laptop have that same NVIDIA GPU? [y/N] " NVIDIA_ANSWER
NVIDIA_ANSWER="${NVIDIA_ANSWER:-N}"
if [[ "$NVIDIA_ANSWER" =~ ^[Yy]$ ]]; then
  echo "Keeping modules/hardware-nvidia.nix enabled."
else
  echo "Will disable modules/hardware-nvidia.nix after copying the repo —"
  echo "falls back to hardware-universal.nix's generic modesetting driver."
fi

# ── Login account ────────────────────────────────────────────────────────────
# flake.nix imports ./user.nix and hands it to every module as `user`;
# configuration.nix then creates users.users.${user.username} with
# initialHashedPassword = user.hashedPassword. Ask for both here and write them
# into the COPIED user.nix after cp below — the checkout this script runs from
# keeps its original values, so `nixos-rebuild switch` on an existing machine
# is unaffected.
USER_NIX="$REPO_DIR/user.nix"
if [ ! -f "$USER_NIX" ]; then
  echo "$USER_NIX not found — flake.nix imports it for the username and password" >&2
  echo "hash, so the install would fail to evaluate. Can't continue." >&2
  exit 1
fi
DEFAULT_USERNAME="$(sed -n 's|^[[:space:]]*username[[:space:]]*=[[:space:]]*"\([^"]*\)".*|\1|p' "$USER_NIX" | head -n1)"
DEFAULT_USERNAME="${DEFAULT_USERNAME:-nixos}"

echo
echo "── Login account ───────────────────────────────────────────────────────"
echo "These go into the installed copy's user.nix. This checkout is left alone,"
echo "so the hash committed to git is never what ends up on the new system."
echo

while :; do
  read -rp "Username [$DEFAULT_USERNAME]: " ACCOUNT_USER
  ACCOUNT_USER="${ACCOUNT_USER:-$DEFAULT_USERNAME}"
  [[ "$ACCOUNT_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] && break
  echo "Invalid username. Lowercase letters, digits, '_' and '-' only, starting" >&2
  echo "with a letter or '_'." >&2
done

while :; do
  read -rsp "Password for $ACCOUNT_USER: " ACCOUNT_PASS; echo
  if [ -z "$ACCOUNT_PASS" ]; then
    echo "Password can't be empty — the account would have no way to log in." >&2
    continue
  fi
  read -rsp "Confirm password: " ACCOUNT_PASS_CONFIRM; echo
  [ "$ACCOUNT_PASS" = "$ACCOUNT_PASS_CONFIRM" ] && break
  echo "Passwords didn't match — try again." >&2
done

# -s reads from stdin rather than argv, so the plaintext never shows up in `ps`.
ACCOUNT_HASH="$(printf '%s\n' "$ACCOUNT_PASS" | mkpasswd -m sha-512 -s)"
unset ACCOUNT_PASS ACCOUNT_PASS_CONFIRM
if [ -z "$ACCOUNT_HASH" ]; then
  echo "mkpasswd returned an empty hash — refusing to install an account whose" >&2
  echo "password can't be verified." >&2
  exit 1
fi
echo "Password hashed (sha-512)."

# ── Copy the repo into place ─────────────────────────────────────────────────
echo "── Copying repo to /mnt/persist/nixos-config ─────────────────────────"
mkdir -p /mnt/persist/nixos-config
cp -a "$REPO_DIR"/. /mnt/persist/nixos-config/
rm -rf /mnt/persist/nixos-config/result  # stale build symlink, if present

if [[ ! "$NVIDIA_ANSWER" =~ ^[Yy]$ ]]; then
  echo "Disabling modules/hardware-nvidia.nix in the copied flake.nix ..."
  sed -i \
    's|^\([[:space:]]*\)\./modules/hardware-nvidia\.nix|\1# ./modules/hardware-nvidia.nix (disabled by setup.sh — no matching NVIDIA GPU)|' \
    /mnt/persist/nixos-config/flake.nix
fi

echo "Writing the login account into the copied user.nix ..."
sed -i \
  -e "s|^\([[:space:]]*\)username[[:space:]]*=.*|\1username = \"$ACCOUNT_USER\";|" \
  -e "s|^\([[:space:]]*\)hashedPassword[[:space:]]*=.*|\1hashedPassword = \"$ACCOUNT_HASH\";|" \
  /mnt/persist/nixos-config/user.nix

# A silent no-match here would quietly install this repo's committed username
# and password hash instead of the ones just entered, so verify rather than
# trust the sed. grep -F because a sha-512 hash is full of regex metacharacters.
if ! grep -qF "username = \"$ACCOUNT_USER\";" /mnt/persist/nixos-config/user.nix \
  || ! grep -qF "hashedPassword = \"$ACCOUNT_HASH\";" /mnt/persist/nixos-config/user.nix; then
  echo "Couldn't write the account into /mnt/persist/nixos-config/user.nix — the" >&2
  echo "install would fall back to this repo's committed hash. Aborting before" >&2
  echo "nixos-install; check that user.nix still has 'username =' and" >&2
  echo "'hashedPassword =' lines." >&2
  exit 1
fi

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
echo "  1. Log in as $ACCOUNT_USER with the password you chose during install."
echo "  2. Restore /persist/secrets/{ssh/,git-identity,claude_api} from your own"
echo "     backup — these were never in git and won't exist yet. See setup.md."
echo "  3. Run 'passwd' any time you want to change the login password."
echo "  4. Clone the Claude Code skills repo (needs the SSH key from step 2):"
echo "       git clone git@github.com:Viscous106/claude-skills.git ~/Viscous/claude-skills"
echo "     then symlink skills/, agents/ and commands/ into ~/.config/claude,"
echo "     and reinstall the Claude Code plugins — both are spelled out in setup.md."
