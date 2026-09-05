{
  description = "Portable NixOS — mouseless on-the-go system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
    # Pinned nixpkgs-unstable's Hyprland (0.54.3) predates native Lua config
    # support (live Arch is on 0.56.2). Track Hyprland's own flake instead.
    # nixpkgs.follows added: Hyprland's own independently-locked nixpkgs drifted
    # to a snapshot where harfbuzz/graphite2/libdatrie ABIs no longer match,
    # breaking the hyprland-guiutils (hyprland-welcome) link step. Following our
    # nixpkgs keeps one consistent snapshot across the whole closure.
    hyprland = {
      url = "github:hyprwm/Hyprland/v0.56.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Quickshell-based desktop shell (bar + notifications + launcher + lock),
    # replacing waybar/swaync. Fetched over git+https rather than github: because
    # the github: fetcher goes through api.github.com and gets 403'd by the
    # unauthenticated rate limit. Its own flake pins quickshell (from outfoxxed's
    # git, it is a different build to nixpkgs' quickshell) plus the caelestia CLI
    # and m3shapes; nixpkgs.follows keeps that whole closure on our single
    # snapshot instead of instantiating a second nixpkgs.
    caelestia-shell = {
      url = "git+https://github.com/caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # skwd-wall — Quickshell wallpaper selector (SUPER+W): images, video and
    # Wallpaper Engine scenes, colour sorting, Wallhaven browser, matugen.
    # ref=main because the default branch (v2) has a flake input pointing at a
    # `nix` branch that does not exist on the GitHub mirror, so it cannot resolve.
    # Both nixpkgs follows matter: left alone it pins its own nixpkgs AND
    # quickshell's (from 2026-01-11), which pulled a second full Qt stack —
    # 211 derivations to build and 2.8 GiB unpacked. Its quickshell is the same
    # revision caelestia already uses (2d3b3e9), so sharing our snapshot lets the
    # two share almost everything.
    skwd-wall = {
      url = "git+https://github.com/liixini/skwd-wall?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.quickshell.inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, zen-browser, antigravity, hyprland, skwd-wall, ... }@inputs:
  let
    system = "x86_64-linux";

    # Everything both machines share. The ONLY difference between the portable
    # USB install and the internal encrypted NVMe install is which
    # hardware-configuration is appended to this list.
    commonModules = [
      ./configuration.nix
      ./modules/hardware-universal.nix
      ./modules/hardware-nvidia.nix
      ./modules/desktop.nix
      ./modules/keyboard.nix
      ./modules/apps-gaming.nix
      ./modules/apps-databases.nix
      ./modules/apps-system.nix
      ./modules/peripherals.nix
      ./modules/audio-glkrt5682max.nix
      ./modules/touchscreen.nix

      hyprland.nixosModules.default
      skwd-wall.nixosModules.default

      home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs    = true;
        home-manager.useUserPackages  = true;
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.backupFileExtension = "backup";
        home-manager.users.viscous    = import ./home/viscous.nix;
      }
    ];

    mkHost = hardware: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = commonModules ++ [ hardware ];
    };
  in
  {
    # Portable USB drive: btrfs by-label, GRUB-as-removable, no NVRAM writes.
    nixosConfigurations.nix = mkHost ./hardware-configuration.nix;

    # Internal NVMe: LUKS2 + btrfs, systemd-boot. hostName is forced to
    # "laptop" there, so `nixos-rebuild switch --flake /persist/nixos-config`
    # resolves to this host automatically once you are booted from it.
    nixosConfigurations.laptop = mkHost ./hardware-configuration-laptop.nix;
  };
}
