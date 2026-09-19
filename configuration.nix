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

      # nixpkgs dropped `opera` on 2025-05-19 (it is a `throw` in aliases.nix
      # now), so we repack Opera's own official .deb. See pkgs/opera.nix.
      opera = final.callPackage ./pkgs/opera.nix { };

      # Quickshell wallpaper selector — a fast keyboard-first picker bound to
      # SUPER+W. Not in nixpkgs; see pkgs/qs-wallpaper-picker.nix for why it
      # needs wrapping rather than being run from a git clone.
      qs-wallpaper-picker = final.callPackage ./pkgs/qs-wallpaper-picker.nix { };

      # Our own Quickshell wallpaper selector; see pkgs/wallpaper-picker.nix and
      # docs/superpowers/specs/2026-09-05-wallpaper-picker-design.md
      wallpaper-picker = final.callPackage ./pkgs/wallpaper-picker.nix { };

      # Reports which OpenAI org/project the Codex CLI is billing — Codex itself
      # only ever shows the auth mode. See pkgs/codex-whoami.nix.
      codex-whoami = final.callPackage ./pkgs/codex-whoami.nix { };

      # Same question for Claude Code — which Anthropic org/workspace is it
      # talking to. Note the two CLIs resolve credentials in opposite
      # directions; see the header of pkgs/claude-whoami.nix.
      claude-whoami = final.callPackage ./pkgs/claude-whoami.nix { };
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

  # ── Journal size cap ──────────────────────────────────────────────────────
  # journald was uncapped and had grown to 3 GB, most of it one kernel warning
  # repeated 46,848 times in a single session (rtw89 RX stats — see the roaming
  # note in modules/hardware-universal.nix). Uncapped journald defaults to 10%
  # of the filesystem, which on a 476 GB root is ~47 GB before it ever rotates.
  # A driver that decides to warn per received frame should not be able to eat
  # the disk, whatever the driver.
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    SystemMaxFileSize=50M
    MaxRetentionSec=1month
  '';

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

    # services.openssh.enable opens port 22 in the firewall by default, so
    # sshd was reachable on every network this laptop joined — verified in the
    # live ruleset: `-A nixos-fw -p tcp --dport 22 -j nixos-fw-accept`. On a
    # machine that roams onto shared office and cafe wifi that is standing
    # attack surface for a service nothing has ever used: `last` shows only
    # reboots, and sshd's journal has no Accepted/session-opened line at all.
    #
    # sshd still runs and still listens locally; what changes is that the
    # firewall no longer admits it from an untrusted link. Remote access is
    # meant to go over Tailscale anyway (services.tailscale.enable above), and
    # tailscale0 is trusted below so SSH keeps working there once you have run
    # `sudo tailscale up` — it currently reports "Logged out".
    #
    # To re-open it on a LAN you trust: openFirewall = true, or scope it with
    # networking.firewall.interfaces.<iface>.allowedTCPPorts = [ 22 ].
    openFirewall = false;
  };

  # Tailscale is a private overlay; traffic arriving on it is already
  # authenticated by Tailscale itself, so it does not need a second gate.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

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
