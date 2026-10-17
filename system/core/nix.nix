{ pkgs, inputs, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store   = true;
    warn-dirty            = false;
  };

  # Weekly GC. The "keep 3 generations" count lives in the prune service below,
  # because nix-collect-garbage can only keep by age or keep exactly one.
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "";
  };

  # Runs before each nix-gc. switch-to-configuration rewrites the boot menu so
  # it never lists generations the GC is about to delete.
  systemd.services.prune-system-generations = {
    description   = "Delete all but the newest 3 NixOS system generations";
    before        = [ "nix-gc.service" ];
    wantedBy      = [ "nix-gc.service" ];
    serviceConfig.Type = "oneshot";
    path          = [ pkgs.nix ];
    script = ''
      nix-env -p /nix/var/nix/profiles/system --delete-generations +3
      /run/current-system/bin/switch-to-configuration boot
    '';
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ (import ../../overlays inputs) ];

  # Lets prebuilt binaries (Mason LSPs, VS Code extensions, AppImages) find a loader.
  programs.nix-ld.enable = true;
}
