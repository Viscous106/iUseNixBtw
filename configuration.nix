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
        system = prev.stdenv.hostPlatform.system;
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
    extraGroups    = [ "wheel" "networkmanager" "video" "audio" "input" "libvirtd" ];
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

  # ── Session variables ─────────────────────────────────────────────────────
  # Arch sets these in /etc/environment, which PAM injects into every session —
  # including the Hyprland session started from the TTY. NixOS had no equivalent,
  # so VISUAL was simply unset inside Hyprland (EDITOR only survived because
  # lua/user_defaults.lua calls hl.env("EDITOR", "nvim")). This restores parity.
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # ── nix-ld ────────────────────────────────────────────────────────────────
  # Lets prebuilt dynamically-linked binaries run unmodified (Mason's
  # downloaded LSP servers/debuggers, VS Code extensions, AppImages, etc.) —
  # without this, anything not built by Nix itself typically fails to find
  # its dynamic loader/libs on NixOS.
  programs.nix-ld.enable = true;

  # ── Tailscale ─────────────────────────────────────────────────────────────
  # Arch had tailscaled actively running; this was left as a bare comment
  # marker and never actually enabled. `services.tailscale.enable` installs
  # the package and starts tailscaled — still needs `sudo tailscale up` once
  # to authenticate this machine.
  services.tailscale.enable = true;


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
