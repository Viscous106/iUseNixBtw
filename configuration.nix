{ config, pkgs, inputs, ... }:

{
  networking.hostName = "nix";
  time.timeZone       = "Asia/Kolkata";
  i18n.defaultLocale  = "en_US.UTF-8";

  # ── Keyboard — DVP (Dvorak Programmer) everywhere ─────────────────────────
  # Applies to Wayland (via libxkbcommon), X11, and the Linux console (TTY).
  services.xserver.xkb = {
    layout  = "us";
    variant = "dvp";
  };

  # Makes the TTY use the same xkb config as the desktop
  console.useXkbConfig = true;

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

  # ── Boot — keep only 3 generations to save ESP space (1 GiB partition) ───
  boot.loader.grub.configurationLimit = 3;

  # ── User ──────────────────────────────────────────────────────────────────
  users.users.viscous = {
    isNormalUser   = true;
    shell          = pkgs.zsh;
    extraGroups    = [ "wheel" "networkmanager" "video" "audio" "input" ];
    # Generate with: mkpasswd -m sha-512
    # Placeholder — change before install or use: sudo nixos-enter --root /mnt -- passwd viscous
    initialPassword = "changeme";
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

  # ── SSH ───────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  programs.ssh = {
    startAgent  = true;
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
