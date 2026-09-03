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

  };

  outputs = { self, nixpkgs, home-manager, zen-browser, antigravity, hyprland, ... }@inputs:
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
