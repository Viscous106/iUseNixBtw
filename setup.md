# Setting up this NixOS config on a new device

This repo is a **portable NixOS install**: `hardware-configuration.nix` uses
generic drivers and filesystem-*by-label* (not by-UUID or by-disk-path), and
GRUB installs itself the "removable media" way (`efiInstallAsRemovable`,
never touches NVRAM). That combination is what makes the exact same config
boot on different physical machines — nothing in here is tied to one
specific laptop.

There are two situations this covers:

- **A brand new disk** (new laptop, new drive, wiped machine) → full
  partition-and-install flow, `setup.sh` does it end to end.
- **This same drive, different machine** → nothing to do. Just plug it in
  and boot. That's the whole point of the by-label/generic-driver setup.

This doc is only about the first case.

## Hardware caveat: NVIDIA is hard-coded, not auto-detected

Everything above is genuinely portable *except* the GPU driver. This repo's
reference machine has an RTX 4050 wired as the only display-capable GPU, and
`modules/hardware-nvidia.nix` — unconditionally imported by `flake.nix` —
forces that with `lib.mkForce [ "nvidia" ]` plus a pinned
`hardware.nvidia.package`. `modules/hardware-universal.nix` only sets a
`mkDefault` fallback (`modesetting`/`fbdev`), which `hardware-nvidia.nix`
always wins over.

`setup.sh` now asks about this directly — partway through the run it prompts:

```
Does THIS laptop have that same NVIDIA GPU? [y/N]
```

Answer `N` (or just press enter) on any machine that isn't that exact RTX
4050 setup, and it comments out the `./modules/hardware-nvidia.nix` line in
the *copied* `flake.nix` (at `/mnt/persist/nixos-config/flake.nix`) before
running `nixos-install` — your original repo checkout is untouched. That
falls back to `hardware-universal.nix`'s generic `modesetting`/`fbdev`
driver, which works on any GPU. Answer `y` only if the new laptop has this
same NVIDIA GPU wired the same way (internal display only reachable through
NVIDIA); everything else in `hardware-universal.nix` (kernel, initrd
modules, network, audio, TLP, zram, etc.) is already hardware-agnostic and
needs no prompt.

If you're re-running `nixos-install` directly (see "If something goes wrong
mid-install" below) rather than through `setup.sh`, there's no prompt — edit
`/mnt/persist/nixos-config/flake.nix` by hand first if you need to drop
`hardware-nvidia.nix`.

## Prerequisites

1. Boot the machine from an **official NixOS installer ISO** (minimal or
   graphical — either works, `setup.sh` only needs `nixos-install`, `sgdisk`,
   `btrfs-progs`, and `git`, all present on the stock ISO).
2. Get on the network (wired usually just works; for Wi-Fi use `nmtui` or
   `nmcli` from the live environment).
3. Know which physical disk you're installing onto. Run `lsblk` if unsure —
   **the whole disk gets wiped**, there's no dual-boot/shrink-existing-partition
   support here.

## Automated install

```bash
git clone <this-repo-url> nixos-config
cd nixos-config
sudo ./setup.sh
```

It will:

1. Show you the available disks and ask which one to wipe — you have to type
   the exact device path back (e.g. `/dev/sda`) to confirm. Nothing destructive
   happens before that confirmation.
2. Partition it: a 1GiB EFI partition (label `EFI`) + the rest as one btrfs
   partition (label `NIXOS`) — matching what's already on the reference drive
   this config was built from.
3. Create the five btrfs subvolumes this config expects: `@` (root, wiped
   fresh at rebuild time — this is an impermanence-style setup),
   `@home`, `@nix`, `@persist` (survives everything, holds this repo + your
   secrets), `@snapshots`.
4. Mount all of that under `/mnt` with the exact options
   `hardware-configuration.nix` declares (`compress=zstd:3`, `discard=async`,
   etc.) — if these ever drift from what's in that file, fix the file, not
   the script (the file is what actually matters at every boot after this
   one; the script only matters once).
5. Copy this repo (the folder you cloned) to `/mnt/persist/nixos-config` —
   including `.git/`, since Nix flakes only evaluate git-tracked files.
6. Run `nixos-install --flake /mnt/persist/nixos-config#nix`.

Expect this to take a while. Two things make the first install slower than a
normal NixOS install:

- **Hyprland is built from its own flake** (`github:hyprwm/Hyprland`), not
  nixpkgs — see the comment in `flake.nix` for why. There's no guaranteed
  binary cache for that, so it may compile from source. If you want to try
  for a cache hit first, add `hyprland.cachix.org` as a substituter on the
  live ISO before running `setup.sh`:
  ```bash
  # on the live ISO, before ./setup.sh
  nix.settings.substituters = [ "https://hyprland.cachix.org" ];
  nix.settings.trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwK1g19er8Vic6ivGUuvsjaqk2iZuT+2=" ];
  ```
  (or just accept the source build — it happens once, not on every rebuild).
- Everything else pulls from `cache.nixos.org` as normal, so it's mostly the
  Hyprland stack that's the wildcard.

## After first boot

The install does **not** restore secrets — they were never in git
(`.gitignore` explicitly excludes `secrets/`), so `setup.sh` can't put back
what it never had. `home-manager`'s activation script creates empty
placeholders on first login so the build doesn't fail, but you still need to
manually copy your real ones onto `/persist/secrets/` from wherever you keep
them (a password manager, an encrypted backup, another machine you can `scp`
from):

```
/persist/secrets/ssh/id_ed25519       # SSH private key
/persist/secrets/ssh/id_ed25519.pub
/persist/secrets/ssh/known_hosts
/persist/secrets/git-identity         # exports GIT_AUTHOR_NAME etc — sourced by zsh
/persist/secrets/claude_api           # exports CLAUDE_API_KEY — sourced by zsh
```

Then:

1. `passwd` — set a real login password (the one baked into
   `configuration.nix` is a hash, not a fresh secret, but change it if you
   want a different one on this install).
2. Log out/in (or reboot) so the shell picks up the restored secrets.
3. `ssh-add -l` should show your key without you doing anything (plain
   `ssh-agent`, `AddKeysToAgent yes` — see the git history for why this isn't
   gnome-keyring).

## If something goes wrong mid-install

`setup.sh` doesn't try to be resumable — if `nixos-install` fails partway
(usually a flake build error, check network first), fix the underlying issue
and just re-run `nixos-install --root /mnt --flake /mnt/persist/nixos-config#nix`
directly; no need to re-partition. Only re-run the whole `setup.sh` (or
`SKIP_PARTITION=1 ./setup.sh` to skip straight to the copy+install step if
`/mnt` is already partitioned and mounted correctly) if you actually want to
wipe and start over.

## What this script deliberately doesn't automate

- **Secrets** — see above. Automating secret restoration would mean the
  secrets exist somewhere automatable, which defeats the point of keeping
  them out of git.
- **Picking a different disk layout** — this repo assumes the whole disk is
  dedicated to this install. If you want dual-boot or a different partition
  scheme, you're on your own for that part; everything after "mount the
  right things at the right paths with the right btrfs subvolumes" is still
  handled by `nixos-install --flake .../nixos-config#nix` same as always.
