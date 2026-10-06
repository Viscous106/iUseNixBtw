# ──────────────────────────────────────────────────────────────────────────────
# The one place this config says who it belongs to.
#
# Everything that used to hardcode "viscous" — the system account in
# configuration.nix, the home-manager key in flake.nix, home.username and
# home.homeDirectory in home/user.nix, the /persist keyring and zen paths —
# now reads these two values instead, handed to every module through
# specialArgs/extraSpecialArgs as `user`.
#
# setup.sh REWRITES THIS FILE in the copy it installs to
# /mnt/persist/nixos-config: it prompts for a username and password on a fresh
# install, hashes the password with `mkpasswd -m sha-512`, and seds both fields
# below. The checkout you are reading keeps the original owner's values, so a
# `nixos-rebuild switch` on an existing machine is unaffected.
#
# It is a tracked file on purpose. Nix flakes only see git-tracked files, so an
# untracked user.nix would be invisible to the evaluator and the build would
# fail with "path does not exist" — which is also why setup.sh edits this file
# in place rather than generating a new one beside it.
#
# To change the password by hand after install, either run `passwd` (imperative,
# wins until the account is recreated) or regenerate the hash here:
#
#   mkpasswd -m sha-512
#
# Note that hashedPassword feeds `initialHashedPassword`, which NixOS applies
# only when the account is first created — editing it on a running system does
# nothing. `passwd` is the right tool there.
# ──────────────────────────────────────────────────────────────────────────────
{
  username = "viscous";

  # Generated with `mkpasswd -m sha-512`.
  hashedPassword = "$6$KAEKKvbZIFl93S.a$bH1h1M.sCzqmvX3SZkK6QcHfjP31vBadi4V/dpWPlL2zIeQ5ZQ85NwrE9sylDZ3Wb/YOeS8lSHtHeJhGbveic0";
}
