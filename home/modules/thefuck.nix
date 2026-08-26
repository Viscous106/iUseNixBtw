{ config, pkgs, ... }:

{
  # ── thefuck ───────────────────────────────────────────────────────────────
  # `thefuck` was removed from nixpkgs (incompatible with Python 3.12+);
  # upstream nixpkgs points to `pay-respects` instead, which zsh.nix already
  # wires up. Config kept here for reference only — no package, not active.
  xdg.configFile."thefuck".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/thefuck";
}
