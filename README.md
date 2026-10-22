# nixos-config

My NixOS + home-manager flake: Hyprland (Lua config) with the caelestia shell,
on a laptop (ASUS, RTX 4050). Two hosts share the same config:

| Host     | Built as                    | What it is                                        |
|----------|-----------------------------|---------------------------------------------------|
| `nix`    | `nixosConfigurations.nix`   | Portable USB install (btrfs by label, removable GRUB) |
| `laptop` | `nixosConfigurations.laptop`| Internal NVMe (LUKS2 + btrfs, systemd-boot)       |

The hostname matches the config name, so `--flake .` picks the right one.
Installing on a new machine: see [setup.md](setup.md).

## Layout

```
flake.nix            inputs + the two hosts
identity.nix         username + password hash (setup.sh rewrites it)
hosts/               per-host hardware: usb.nix, nvme.nix, nvidia.nix
overlays/            package overrides + local packages from pkgs/
pkgs/                local derivations and patches
lib/import-dir.nix   auto-import helper

system/              NixOS (both hosts)
  core/              nix settings + GC, base system, user account
  hardware/          kernel/firmware/power, audio, keyboard, touchscreen, ASUS
  services/          databases, virtualisation, gaming, Proton Drive mount, atuin server
  network.nix        NetworkManager/iwd, DNS, Tailscale, SSH, firewall
  desktop.nix        Hyprland, portals, fonts, Thunar, bluetooth
  packages.nix       system-wide CLI tools

home/                home-manager
  desktop/           Hyprland, caelestia, theming, fonts, session tools
  shell/             zsh, tmux, atuin, git, gpg, kitty, CLI tools
  dev/               neovim, toolchains, python, web3, AI agents
  apps/              browsers, media, misc
  services/          user daemons (battery)
  dotfiles.nix       every live-edit symlink, in one table
  default.nix        identity, web3 knobs, secrets activation

dotfiles/            raw app configs (hypr, nvim, tmux, zsh, rofi, …)
docs/design/         design notes for the bigger custom pieces
```

Every `.nix` file under `system/` and `home/` is imported automatically.
`hosts/nvidia.nix` is the exception: it is listed in `flake.nix` so `setup.sh`
can comment it out on machines without an NVIDIA GPU.

## Common tasks

**Rebuild** (aliases from `home/shell/zsh.nix`):

```sh
rebuild        # sudo nixos-rebuild switch --flake /persist/nixos-config
update         # nix flake update, then rebuild
nixos-rebuild build --flake .#nix   # build the other host without switching
```

New files must be `git add`-ed before a rebuild — flakes only see tracked files.

**Add a package.** Put it in the module for its topic, e.g. a CLI tool in
`home/shell/cli.nix`, a GUI app in `home/apps/*.nix`, something root needs in
`system/packages.nix`.

**Add a module.** Create a `.nix` file in the right folder under `system/` or
`home/`. No import list to edit.

**Add a live-edit config.** Put the files in `dotfiles/<app>/` and add one line
to `configLinks` (or `homeLinks` for non-XDG paths) in `home/dotfiles.nix`.
After one rebuild, edits in `dotfiles/` apply immediately.

Files that are *not* live (need a rebuild): `dotfiles/hypr/hyprlock.conf`
(rendered with `@HOME@` substituted) and anything set through Nix options.

## Pinned inputs

Most inputs follow `nixpkgs` and move together with `nix flake update`.
Exceptions, each explained in `flake.nix`:

- **`nixpkgs-claude`** — pinned by revision so claude-code can move faster than
  the system. `nix flake update` does not move it; bump with
  `curl -sL https://channels.nixos.org/nixos-unstable-small/git-revision`
  and paste the rev into `flake.nix`.
- **`hyprland`** — pinned to a release tag (Lua config needs ≥ 0.56). The glaze
  pin it needs is in `overlays/default.nix`.
- **`atuin`** — patched locally (`pkgs/atuin-*.patch`), so it builds from source.
