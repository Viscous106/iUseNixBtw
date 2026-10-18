{
  description = "Portable NixOS — mouseless on-the-go system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # wivrn only (system/services/vr.nix): must match the headset client, which the Meta Store auto-updates.
    # Bump with `nix flake update nixpkgs-wivrn`; drop once nixos-unstable catches up.
    nixpkgs-wivrn.url = "github:NixOS/nixpkgs/nixos-unstable-small";

    # claude-code only (overlays/default.nix), separate so bumps can't break the headset. Rev-pinned (api.github.com
    # rate limit), so bump by hand: curl -sL https://channels.nixos.org/nixos-unstable-small/git-revision
    nixpkgs-claude.url = "github:NixOS/nixpkgs/94d35c7c05087e8b07373a403c55e97d99ff9af9";  # claude-code 2.1.296

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows     = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };

    antigravity = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Hyprland's own flake for native Lua config; nixpkgs.follows avoids
    # ABI mismatches (harfbuzz etc.) from a second nixpkgs snapshot.
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.56.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop shell (bar, notifications, launcher, lock). git+https because the
    # github: fetcher hits the unauthenticated api.github.com rate limit.
    caelestia-shell = {
      url = "git+https://github.com/caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
    };

    # Prebuilt nix-locate database so pay-respects' command-not-found lookups
    # work without running `nix-index` by hand.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Local checkout (home/dev/claude-lend.nix); git+file copies only tracked files.
    # After changing it: `nix flake update claude-lend`.
    claude-lend = {
      url = "git+file:///home/viscous/Viscous/I-have-claude-BTW";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, hyprland, ... }@inputs:
  let
    system = "x86_64-linux";

    # Username + password hash; setup.sh rewrites identity.nix on install.
    # Passed to every module as `user`.
    user = import ./identity.nix;

    # Shared by both hosts; they differ only in the hosts/<name>.nix file.
    commonModules = [
      ./system                 # imports every .nix under system/
      ./hosts/nvidia.nix       # explicit so setup.sh can comment it out

      hyprland.nixosModules.default

      home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs    = true;
        home-manager.useUserPackages  = true;
        home-manager.extraSpecialArgs = { inherit inputs user; };
        home-manager.backupFileExtension = "backup";
        home-manager.users.${user.username} = import ./home;
      }
    ];

    mkHost = host: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs user; };
      modules = commonModules ++ [ host ];
    };
  in
  {
    # Portable USB drive: btrfs by label, GRUB as removable, no NVRAM writes.
    nixosConfigurations.nix = mkHost ./hosts/usb.nix;

    # Internal NVMe: LUKS2 + btrfs, systemd-boot.
    nixosConfigurations.laptop = mkHost ./hosts/nvme.nix;
  };
}
