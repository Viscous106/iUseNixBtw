{ config, pkgs, inputs, ... }:

{
  networking.hostName = "nix";
  time.timeZone       = "Asia/Kolkata";
  i18n.defaultLocale  = "en_US.UTF-8";
  networking.networkmanager.enable=true;
  # ── Nix settings ──────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store   = true;
      warn-dirty            = false;
    };
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 30d";
    };
  };
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import inputs.nixpkgs {
        system = prev.system;
        config.allowUnfree = true;
      };
    })
  ];
  # ── Boot — keep only 3 generations to save ESP space (1 GiB partition) ───
  boot.loader.grub.configurationLimit = 3;

  # ── User ──────────────────────────────────────────────────────────────────
  users.users.viscous = {
    isNormalUser   = true;
    shell          = pkgs.zsh;
    extraGroups    = [ "wheel" "networkmanager" "video" "audio" "input" ];
    # Password hash generated with mkpasswd -m sha-512
    initialHashedPassword = "$6$KAEKKvbZIFl93S.a$bH1h1M.sCzqmvX3SZkK6QcHfjP31vBadi4V/dpWPlL2zIeQ5ZQ85NwrE9sylDZ3Wb/YOeS8lSHtHeJhGbveic0";
  };

  security.sudo.wheelNeedsPassword = false;

  # ── Base packages ─────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git curl wget vim
    btrfs-progs gptfdisk parted
    pciutils usbutils lshw
    htop btop
  ];

  # ── Shell ─────────────────────────────────────────────────────────────────
  programs.zsh.enable = true;

  # ── Keyring ───────────────────────────────────────────────────────────────
  services.gnome.gnome-keyring.enable = true;
  # components: ssh, secrets, pkcs11
  programs.seahorse.enable = true;

  # ── SSH ───────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  security.pam.services.login.enableGnomeKeyring = true;

  programs.ssh = {
    startAgent  = false;
    agentTimeout = "4h";
    extraConfig = ''
      Host *
        AddKeysToAgent     yes
        IdentityFile       /persist/secrets/ssh/id_ed25519
        ServerAliveInterval 60
    '';
  };

  system.stateVersion = "25.05";
}
