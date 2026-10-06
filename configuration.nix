{ config, pkgs, inputs, user, ... }:

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
    # Keep the newest 3 system generations, nothing older.
    #
    # The count lives in systemd.services.prune-system-generations below, NOT
    # here: nix-collect-garbage can only express "--delete-old" (which keeps
    # exactly one) or "--delete-older-than <period>" (age, not count). Neither
    # says "keep 3". So that service prunes by count first and this just sweeps
    # whatever it unrooted.
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "";
    };
  };

  # Prune system generations to the newest 3, then rewrite the boot menu.
  #
  # The switch-to-configuration call is not optional: systemd-boot's ESP
  # entries are only regenerated on a rebuild, so deleting generations without
  # it leaves menu entries pointing at store paths the following GC removes —
  # i.e. entries that fail at boot. Ordered before nix-gc.service and pulled in
  # by it, so it rides the existing weekly nix-gc.timer rather than adding one.
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
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import inputs.nixpkgs {
        system = prev.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };

      # claude-code from its own pinned input rather than the main snapshot,
      # so the CLI can be bumped on its own cadence. See the long note on the
      # nixpkgs-claude input in flake.nix. Overriding the attr (rather than
      # exposing a second pkgs set) means every consumer — home.packages here,
      # anything reaching for pkgs.claude-code later — gets the pinned build.
      claude-code = (import inputs.nixpkgs-claude {
        system = prev.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      }).claude-code;

      # nixpkgs dropped `opera` on 2025-05-19 (it is a `throw` in aliases.nix
      # now), so we repack Opera's own official .deb. See pkgs/opera.nix.
      opera = final.callPackage ./pkgs/opera.nix { };

      # Our own Quickshell wallpaper selector; see pkgs/wallpaper-picker.nix and
      # docs/superpowers/specs/2026-09-05-wallpaper-picker-design.md
      wallpaper-picker = final.callPackage ./pkgs/wallpaper-picker.nix { };

      # Animated region selector standing in for slurp in the screenshot and
      # screen-recording scripts; see pkgs/rope-select.nix.
      rope-select = final.callPackage ./pkgs/rope-select.nix { };

      # Reports which OpenAI org/project the Codex CLI is billing — Codex itself
      # only ever shows the auth mode. See pkgs/codex-whoami.nix.
      codex-whoami = final.callPackage ./pkgs/codex-whoami.nix { };

      # Same question for Claude Code — which Anthropic org/workspace is it
      # talking to. Note the two CLIs resolve credentials in opposite
      # directions; see the header of pkgs/claude-whoami.nix.
      claude-whoami = final.callPackage ./pkgs/claude-whoami.nix { };

      # Builder for a pinned Solidity compiler from upstream's static release
      # binaries — nixpkgs carries only one solc, and following older material
      # needs older ones. Called as `pkgs.solc-bin { version; sha256; }` from
      # home/modules/web3.nix; see pkgs/solc-bin.nix for why it is a plain
      # fetchurl with no autoPatchelf.
      solc-bin = final.callPackage ./pkgs/solc-bin.nix { };
    })
  ];
  # ── Boot — keep only 3 generations to save ESP space (1 GiB partition) ───
  boot.loader.grub.configurationLimit = 3;

  # ── User ──────────────────────────────────────────────────────────────────
  # Name and password both come from ./user.nix, which setup.sh rewrites on a
  # fresh install from what the installer typed at the prompt. Nothing here
  # hardcodes an account.
  users.users.${user.username} = {
    isNormalUser   = true;
    shell          = pkgs.zsh;
    extraGroups    = [ "wheel" "networkmanager" "video" "audio" "input" "libvirtd" ];
    # Password hash generated with mkpasswd -m sha-512 (see ./user.nix).
    # initialHashedPassword, not hashedPassword, so `passwd` keeps working
    # afterwards: NixOS applies this only when the account is first created.
    initialHashedPassword = user.hashedPassword;
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

  # ── Core dumps ────────────────────────────────────────────────────────────
  # Turned off. xdg-desktop-portal-hyprland segfaults on every output teardown
  # — monitor unplug, DPMS cycle, session exit — destroying an SOutput, which
  # destroys its zxdg_output_v1 proxy and marshals a destroy request against an
  # already-torn-down Wayland object map. That is upstream's bug (the dtor at
  # protocols/xdg-output-unstable-v1.cpp:186), not ours, and until it is fixed
  # it fires once or twice a day. Every crash wrote a 27 MB core.PID into the
  # cwd of the crashing process — which for a session daemon is $HOME — so ten
  # of them had piled up in ~ by 2026-10-03.
  #
  # Disabling systemd-coredump alone does not fix it: the module then sets
  # kernel.core_pattern to the bare string "core", which is exactly what put
  # the files in $HOME to begin with. The limit is what actually suppresses the
  # dump — the kernel skips dumping when RLIMIT_CORE is 0, but only for file
  # patterns, because a piped core_pattern ignores the limit entirely. So both
  # halves are needed: no pipe, and a zero limit on each of the three paths
  # that sets one (PID 1 for system services, the per-user manager, and PAM for
  # login sessions).
  #
  # Zeroed as a soft limit with the hard limit left alone, so `ulimit -c
  # unlimited` in one shell still gets you a dump when you actually want to
  # debug something, without root. For the full picture instead, comment this
  # block out and rebuild: that restores systemd-coredump, and dumps land in
  # /var/lib/systemd/coredump with rotation, readable via coredumpctl.
  systemd.coredump.enable = false;
  systemd.settings.Manager.DefaultLimitCORE = "0:infinity";
  systemd.user.settings.Manager.DefaultLimitCORE = "0:infinity";
  security.pam.loginLimits = [
    { domain = "*"; item = "core"; type = "soft"; value = "0"; }
  ];

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

  # ── DNS — local cache, fast upstream, Tailscale kept for ts.net only ──────
  # Symptom: the link is fast (190-250 Mbit/s measured) but pages stall before
  # they start. The stall is name resolution, not bandwidth. On a cold `curl`
  # over eight real sites, time_namelookup ran 39-92 ms typical with one at
  # 865 ms (archlinux.org) — on a 50 MB Cloudflare download, DNS was 90 ms of a
  # 174 ms time-to-first-byte. More than half the wait to first byte was spent
  # finding out where to send the request.
  #
  # Two separate causes, both of them configuration:
  #
  # 1. There was no DNS cache on this machine at all. systemd-resolved was
  #    inactive and nothing else cached, so every lookup — including the same
  #    handful of domains, over and over — went out to the network. A page that
  #    pulls from a dozen hosts paid that a dozen times.
  #
  # 2. /etc/resolv.conf listed exactly one resolver: 100.100.100.100. That is
  #    tailscaled's in-process DNS proxy, and `tailscale dns status` reports
  #    "no resolvers configured" with a single split route for ts.net. So every
  #    query for every domain was being handed to a userspace proxy whose only
  #    real job here is ts.net, which then forwarded it back out to the router
  #    anyway. Measured on cached names, that detour cost 19.2 ms median
  #    against the router's 1.7 ms.
  #
  # On uncached names (random labels, forcing full recursion) the upstream
  # itself is also the wrong choice — median over eight queries:
  #
  #   tailscale 100.100.100.100   185.7 ms
  #   router    192.168.0.1       267.2 ms   (the ISP resolver behind it)
  #   cloudflare 1.1.1.1           42.3 ms
  #
  # resolved fixes both axes at once: it caches, so the repeat lookups that
  # dominate real browsing become local, and it queries 1.1.1.1 directly
  # instead of the ISP, so the misses are ~6x faster.
  #
  # Tailscale is NOT disabled here and MagicDNS keeps working. tailscaled
  # detects systemd-resolved and registers split DNS over its D-Bus API, so
  # ts.net goes to Tailscale and everything else goes to the resolvers below —
  # which is the arrangement the single split route above was always asking
  # for. This is upstream's preferred integration, not a workaround.
  #
  # DNSSEC and DNSOverTLS are left off deliberately. This laptop roams onto
  # café and office wifi; both break captive portals, and DoT adds a handshake
  # to the first query on every new network. Turn DNSOverTLS on if the machine
  # stops moving.
  #
  # Verify after a rebuild:
  #   resolvectl status          -> "DNS Servers: 1.1.1.1 ..." + ts.net domain
  #   resolvectl statistics      -> cache hits climbing
  #   ping laptop.tail4ba78e.ts.net
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS  = [ "1.1.1.1" "1.0.0.1" "9.9.9.9" ];
      DNSOverTLS = false;
      DNSSEC     = false;
      Cache      = true;
    };
  };

  # Hand NM's DNS to resolved instead of resolvconf. Without this NM keeps
  # rc-manager=resolvconf and races resolved for /etc/resolv.conf — which
  # resolved wants to own as a symlink to its stub (127.0.0.53).
  networking.networkmanager.dns = "systemd-resolved";

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
