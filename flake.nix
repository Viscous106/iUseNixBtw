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
    # support (live Arch is on 0.56.2). Track Hyprland's own flake instead —
    # deliberately NOT following our nixpkgs; Hyprland pins exact versions of
    # its own ecosystem libs (aquamarine, hyprutils, ...) and following our
    # nixpkgs risks a version mismatch across them.
    hyprland.url = "github:hyprwm/Hyprland/v0.56.2";

  };

  outputs = { self, nixpkgs, home-manager, zen-browser, antigravity, hyprland, ... }@inputs:
  let
    system = "x86_64-linux";
  in
  {
    nixosConfigurations.nix = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        ./modules/hardware-universal.nix
        ./modules/desktop.nix
        ./modules/keyboard.nix
        ./modules/apps-gaming.nix
        ./modules/apps-databases.nix
        ./modules/apps-system.nix

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
    };
  };
}
