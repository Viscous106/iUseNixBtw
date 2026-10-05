{ config, pkgs, ... }:

# ── Cross-platform disk encryption: VeraCrypt ─────────────────────────────
# Added for the Kingston XS1000 external drive (/dev/sda), split into an
# unencrypted exFAT partition (sda1, label "one-for-all") and a 1 TB
# VeraCrypt partition (sda2), plus a VeraCrypt file *container* living on
# sda1 — the container is the only form Android/iOS can open, because those
# platforms expose no raw block access to an unrooted app and will not mount
# a partition whose filesystem they cannot identify.
#
# Replaces the ad-hoc `NIXPKGS_ALLOW_UNFREE=1 nix-shell -p veracrypt`
# invocation that was being used to reach the binary.
#
# Deliberately NOT redefined here — all four already exist elsewhere in this
# config, and two of them would be evaluation errors if duplicated rather
# than merges:
#
#   - nixpkgs.config.allowUnfree (configuration.nix). veracrypt ships under
#     the TrueCrypt License 3.0 and is marked unfree. Note the system-level
#     setting does NOT cover `nix-shell -p veracrypt`: that reads
#     ~/.config/nixpkgs/config.nix instead, which is why the throwaway shell
#     needed NIXPKGS_ALLOW_UNFREE=1 and this module does not.
#   - exfatprogs (modules/apps-system.nix:157). veracrypt shells out to
#     mkfs.exfat for `--filesystem=exFAT`; without it that option just
#     disappears from the format list instead of erroring. pkgs.veracrypt is
#     a wrapper, but it sets only GIO/GSETTINGS vars (verified with strings
#     against the 1.26.29 output) and no PATH override, so it inherits the
#     caller's PATH and picks up the system mkfs.exfat.
#   - programs.fuse.userAllowOther (modules/proton.nix:142). veracrypt
#     mounts a FUSE helper filesystem alongside each volume. Redefining this
#     bool in a second module is an option conflict, not a merge.
#   - cryptsetup — already in systemPackages via the NixOS luksroot module,
#     which hardware-configuration-laptop.nix:49 pulls in through
#     boot.initrd.luks.devices."cryptroot". That is the no-VeraCrypt escape
#     hatch for this drive:
#       sudo cryptsetup open --type tcrypt --veracrypt /dev/sda2 vault
#     The --veracrypt flag is not optional: plain `--type tcrypt` scans for
#     TrueCrypt headers only. Expect a 30s-to-minutes unlock, since it brute
#     forces every cipher/hash combination against 500k PBKDF2 iterations.
#
# security.sudo.wheelNeedsPassword = false (configuration.nix:76) means
# veracrypt's internal privilege escalation — loop-device setup when creating
# a container, and mounting — happens with no password prompt on this
# machine. It will prompt on any other.
{
  environment.systemPackages = [ pkgs.veracrypt ];
}
