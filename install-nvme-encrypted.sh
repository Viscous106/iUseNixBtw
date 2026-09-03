#!/usr/bin/env bash
# ==============================================================================
# Internal NVMe — encrypted install (LUKS2 + btrfs + systemd-boot)
#
# Counterpart to setup.sh. setup.sh builds the portable USB drive; this builds
# the fixed, encrypted internal disk. Run it BOOTED FROM THE USB DRIVE — that
# is what leaves the NVMe idle enough to wipe, and it means the Nix store is
# already warm, so the install mostly copies locally instead of downloading.
#
#   sudo ./install-nvme-encrypted.sh
#
# What it does, in one unattended run after the confirmations:
#   1. Wipes the target NVMe                                      — DESTRUCTIVE
#   2. GPT: 1 GiB ESP (partlabel nixesp) + LUKS2 (partlabel nixcrypt)
#   3. Generates a recovery passphrase into keyslot 1, backs up the LUKS header
#   4. btrfs: @ @home @nix @persist @snapshots @swap + an 8 GiB NOCOW swapfile
#   5. Copies this repo AND /persist/secrets onto the new root
#   6. Copies /home across from a read-only snapshot of the USB's @home
#   7. nixos-install --flake ...#laptop
#
# The partition names in step 2 are what hardware-configuration-laptop.nix
# points at (/dev/disk/by-partlabel/...), which is why nothing in this script
# ever has to rewrite UUIDs into a .nix file.
#
# Env overrides for re-runs after a failure:
#   SKIP_PARTITION=1  /mnt is already set up the way this script leaves it
#   SKIP_HOME=1       don't copy /home across (do it later by hand)
#   TARGET=/dev/nvme0n1   skip autodetection
# ==============================================================================
set -euo pipefail

RECOVERY_NOTE=""

die() { echo; echo "ERROR: $*" >&2; exit 1; }
say() { echo; echo "── $* ──────────────────────────────────────────────────" | cut -c1-79; }

[ "$(id -u)" -eq 0 ] || die "Run as root: sudo ./install-nvme-encrypted.sh"

# ── Dependency self-heal (same trick as setup.sh) ────────────────────────────
declare -A _CMD_TO_PKG=(
  [cryptsetup]=cryptsetup  [wipefs]=util-linux    [sgdisk]=gptfdisk
  [partprobe]=parted       [mkfs.fat]=dosfstools  [mkfs.btrfs]=btrfs-progs
  [btrfs]=btrfs-progs      [rsync]=rsync          [lsblk]=util-linux
  [udevadm]=systemd        [base32]=coreutils     [findmnt]=util-linux
)
_MISSING=()
for _c in "${!_CMD_TO_PKG[@]}"; do
  command -v "$_c" >/dev/null 2>&1 || _MISSING+=("${_CMD_TO_PKG[$_c]}")
done
if [ "${#_MISSING[@]}" -gt 0 ]; then
  [ -n "${NIXOS_ENC_REEXEC:-}" ] && die "still missing after re-exec: ${_MISSING[*]}"
  command -v nix-shell >/dev/null 2>&1 || die "missing ${_MISSING[*]} and no nix-shell"
  mapfile -t _MISSING < <(printf '%s\n' "${_MISSING[@]}" | sort -u)
  echo "Fetching: ${_MISSING[*]}"
  exec nix-shell -p "${_MISSING[@]}" \
    --run "NIXOS_ENC_REEXEC=1 exec bash $(printf '%q' "${BASH_SOURCE[0]}") ${*@Q}"
fi

command -v nixos-install >/dev/null 2>&1 \
  || die "nixos-install not found — boot the USB NixOS (or a NixOS ISO) first."

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$REPO_DIR/hardware-configuration-laptop.nix" ] \
  || die "$REPO_DIR has no hardware-configuration-laptop.nix — wrong directory?"

# ── Where are we running from? ───────────────────────────────────────────────
ROOT_SRC="$(findmnt -no SOURCE / | sed 's/\[.*\]//')"
ROOT_DISK="$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null || true)"
[ -n "$ROOT_DISK" ] || die "can't determine which disk / lives on"

# ── Target selection ─────────────────────────────────────────────────────────
if [ -n "${TARGET:-}" ]; then
  DISK="$TARGET"
else
  mapfile -t CANDIDATES < <(lsblk -dno NAME,TRAN | awk '$2=="nvme"{print "/dev/"$1}')
  CANDIDATES=("${CANDIDATES[@]/#/}")
  FILTERED=()
  for d in "${CANDIDATES[@]}"; do [ "$(basename "$d")" != "$ROOT_DISK" ] && FILTERED+=("$d"); done
  [ "${#FILTERED[@]}" -eq 1 ] \
    || die "expected exactly one internal NVMe that isn't the running root; found: ${FILTERED[*]:-none}. Set TARGET=/dev/nvmeXnY."
  DISK="${FILTERED[0]}"
fi

[ -b "$DISK" ] || die "$DISK is not a block device"
[ "$(basename "$DISK")" != "$ROOT_DISK" ] \
  || die "$DISK is the disk you are currently running from. Boot the USB drive first."

if [[ "$DISK" == *nvme* ]]; then ESP="${DISK}p1"; LUKS="${DISK}p2"
else                             ESP="${DISK}1";  LUKS="${DISK}2"; fi

# ── Confirm ──────────────────────────────────────────────────────────────────
say "Target"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISK"
cat <<EOF

Running from : $ROOT_SRC  (disk: $ROOT_DISK)
Will destroy : $DISK
  $ESP   1 GiB   FAT32, partlabel 'nixesp', label NIXBOOT
  $LUKS  rest    LUKS2 aes-xts-plain64/512 argon2id, partlabel 'nixcrypt'
                 └─ btrfs 'nixroot': @ @home @nix @persist @snapshots @swap

EVERY BYTE ON $DISK IS ERASED. There is no undo after this point.
The USB drive you are running from is not touched, and stays bootable.

EOF
read -rp "Type the disk path exactly ($DISK) to confirm: " CONFIRM
[ "$CONFIRM" = "$DISK" ] || die "confirmation didn't match — nothing was touched"

if grep -qs "$DISK" /proc/mounts; then
  say "Unmounting stale mounts on $DISK"
  umount -R "$DISK"* 2>/dev/null || true
fi

if [ "${SKIP_PARTITION:-0}" = "1" ]; then
  say "SKIP_PARTITION=1 — assuming /mnt is already mounted"
else
  # ── Partition ──────────────────────────────────────────────────────────────
  say "Partitioning $DISK"
  wipefs -a "$DISK"
  sgdisk --zap-all "$DISK"
  sgdisk --new=1:0:+1GiB --typecode=1:ef00 --change-name=1:nixesp   "$DISK"
  sgdisk --new=2:0:0     --typecode=2:8309 --change-name=2:nixcrypt "$DISK"
  partprobe "$DISK"; udevadm settle; sleep 2

  [ -e /dev/disk/by-partlabel/nixesp ] && [ -e /dev/disk/by-partlabel/nixcrypt ] \
    || die "/dev/disk/by-partlabel/{nixesp,nixcrypt} did not appear — hardware-configuration-laptop.nix depends on those names"

  mkfs.fat -F32 -n NIXBOOT "$ESP"

  # ── LUKS2 ──────────────────────────────────────────────────────────────────
  say "Encrypting $LUKS"
  cat <<'EOF'
You are about to set the passphrase that unlocks this machine at every boot.

  * The initrd prompt uses PLAIN US QWERTY. Your keyd/kanata remaps do not
    exist yet at that point. Pick something typeable on an unmodified layout.
  * 5-6 random words beats a short cryptic string: more entropy, less typo.
  * Nothing recovers a forgotten passphrase. Write it down before continuing.

EOF
  cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 --key-size 512 --hash sha512 \
    --pbkdf argon2id --iter-time 5000 \
    --label NIXCRYPT \
    "$LUKS"

  # ── Recovery keyslot ───────────────────────────────────────────────────────
  # Written with no trailing newline, so feeding the file and typing the same
  # characters at a prompt produce identical key material — it works both as a
  # keyfile here and as a passphrase you can type in an emergency.
  say "Adding a recovery passphrase to keyslot 1"
  RECOVERY="$(head -c 30 /dev/urandom | base32 | tr -d '=\n' | fold -w5 | paste -sd- -)"
  RECOVERY_FILE=/run/nvme-recovery.key
  printf '%s' "$RECOVERY" > "$RECOVERY_FILE"
  chmod 600 "$RECOVERY_FILE"
  echo "Enter the passphrase you just set, once, to authorise the extra keyslot:"
  cryptsetup luksAddKey "$LUKS" "$RECOVERY_FILE"

  if [ -d /persist/secrets ]; then
    printf '%s\n' "$RECOVERY" > /persist/secrets/nvme-recovery-key.txt
    chmod 600 /persist/secrets/nvme-recovery-key.txt
    RECOVERY_NOTE="/persist/secrets/nvme-recovery-key.txt (on the USB drive)"
  fi

  # ── Open + filesystems ─────────────────────────────────────────────────────
  say "Opening the container"
  cryptsetup open "$LUKS" cryptroot --allow-discards --persistent --key-file "$RECOVERY_FILE"
  cryptsetup status cryptroot | head -8

  say "Backing up the LUKS header"
  if [ -d /persist/secrets ]; then
    rm -f /persist/secrets/nvme-luks-header.img
    cryptsetup luksHeaderBackup "$LUKS" --header-backup-file /persist/secrets/nvme-luks-header.img
    chmod 600 /persist/secrets/nvme-luks-header.img
  else
    echo "no /persist/secrets on this system — skipping (take one by hand later)"
  fi

  say "Creating btrfs subvolumes"
  mkfs.btrfs -f -L nixroot /dev/mapper/cryptroot
  mount /dev/mapper/cryptroot /mnt
  for sv in @ @home @nix @persist @snapshots @swap; do
    btrfs subvolume create "/mnt/$sv"
  done
  umount /mnt

  say "Mounting (must match hardware-configuration-laptop.nix exactly)"
  O=noatime,compress=zstd:3,space_cache=v2,discard=async
  mount -o "subvol=@,${O},autodefrag"     /dev/mapper/cryptroot /mnt
  mkdir -p /mnt/{home,nix,persist,.snapshots,swap,boot}
  mount -o "subvol=@home,${O},autodefrag" /dev/mapper/cryptroot /mnt/home
  mount -o "subvol=@nix,${O}"             /dev/mapper/cryptroot /mnt/nix
  mount -o "subvol=@persist,${O}"         /dev/mapper/cryptroot /mnt/persist
  mount -o "subvol=@snapshots,${O}"       /dev/mapper/cryptroot /mnt/.snapshots
  mount -o "subvol=@swap,noatime"         /dev/mapper/cryptroot /mnt/swap
  mount -o fmask=0077,dmask=0077          "$ESP"                /mnt/boot

  say "Creating the 8 GiB swapfile"
  btrfs filesystem mkswapfile --size 8g --uuid clear /mnt/swap/swapfile
fi

findmnt -R /mnt -o TARGET,SOURCE,FSTYPE | head -20

# ── Config + secrets ─────────────────────────────────────────────────────────
say "Copying the config repo"
mkdir -p /mnt/persist/nixos-config
rsync -a --delete --exclude=result "$REPO_DIR"/ /mnt/persist/nixos-config/

if [ -d /persist/secrets ]; then
  say "Copying /persist/secrets"
  rsync -aHAX /persist/secrets/ /mnt/persist/secrets/
  # The recovery key and header backup are worthless stored on the disk they
  # unlock — they belong on the USB drive and offline, not here.
  rm -f /mnt/persist/secrets/nvme-recovery-key.txt /mnt/persist/secrets/nvme-luks-header.img
else
  mkdir -p /mnt/persist/secrets/ssh && chmod 700 /mnt/persist/secrets/ssh
fi

# ── Home ─────────────────────────────────────────────────────────────────────
if [ "${SKIP_HOME:-0}" = "1" ]; then
  say "SKIP_HOME=1 — not copying /home"
elif [ "$ROOT_SRC" != "/dev/mapper/cryptroot" ] && [ -d /home ]; then
  say "Copying /home from a read-only snapshot of the USB's @home"
  # Snapshot first: rsyncing a live home while a desktop session writes to it
  # gives you a subtly inconsistent copy.
  USBTOP=/run/usb-btrfs-top
  mkdir -p "$USBTOP"
  mount -o subvolid=5 "$ROOT_SRC" "$USBTOP"
  SNAP="$USBTOP/@home-installsnap"
  btrfs subvolume delete "$SNAP" 2>/dev/null || true
  btrfs subvolume snapshot -r "$USBTOP/@home" "$SNAP"
  rsync -aHAX --info=progress2 "$SNAP"/ /mnt/home/
  btrfs subvolume delete "$SNAP"
  umount "$USBTOP" && rmdir "$USBTOP"
fi

# ── Install ──────────────────────────────────────────────────────────────────
say "Installing"
echo "Using path: so the flake is read straight from disk — no 'git add' needed"
echo "for hardware-configuration-laptop.nix, which flakes would otherwise skip."
echo
nixos-install --root /mnt --flake "path:/mnt/persist/nixos-config#laptop" --no-root-passwd

# ── Done ─────────────────────────────────────────────────────────────────────
say "Done"
cat <<EOF
Before you reboot:

  Recovery passphrase (keyslot 1) — WRITE IT DOWN, it is not stored anywhere
  on the new system:

      ${RECOVERY:-<not generated: SKIP_PARTITION was set>}

  ${RECOVERY_NOTE:+Also saved to $RECOVERY_NOTE — move it offline and delete it.}
  LUKS header backup: /persist/secrets/nvme-luks-header.img (on the USB drive).
  Copy both off this machine. A lost header means the data is unrecoverable
  even with the right passphrase.

Then:

  umount -R /mnt && swapoff -a; cryptsetup close cryptroot && reboot

Pick the internal disk in the firmware boot menu. Expect: systemd-boot menu →
LUKS passphrase prompt → NixOS. Log in as viscous with the password from
configuration.nix's initialHashedPassword.

Keep the USB drive as-is for a few days. It is your only fallback until the
internal install has proven itself; encrypting it is a separate, later step
(see encrypted-install.md, phase 5).
EOF
