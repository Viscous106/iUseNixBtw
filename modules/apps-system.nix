{ config, pkgs, lib, ... }:

# ── System utilities, networking, security, filesystem & calendar tools ───
# Ported from the Arch install's explicitly-installed package list. Every
# attribute below was verified to exist by grepping the fetched nixpkgs
# source tree (pkgs/by-name + pkgs/top-level/*.nix + nixos/modules/**) before
# being added — nothing here is guessed. See the accompanying migration
# report for what was skipped as already-covered-elsewhere (duplicated in a
# parallel home-manager module, or already handled by hardware-universal.nix
# / desktop.nix) and for the firewall/tor/gvfs judgment calls.

{
  # ── Firewall ──────────────────────────────────────────────────────────────
  # Arch had firewalld + ufw + iptables all installed simultaneously (three
  # overlapping firewall managers — clutter, only one was realistically
  # active). NixOS-idiomatic choice: rely on the BUILT-IN
  # `networking.firewall` (nftables-backed, enabled by default and not
  # touched/disabled anywhere in this repo) rather than layering firewalld
  # on top.
  #   - firewalld is NOT enabled here: `services.firewalld.enable` disables
  #     the built-in `networking.firewall` module outright, which would also
  #     break `programs.kdeconnect.enable` below (it opens its ports via
  #     `networking.firewall.allowedTCPPortRanges`, a no-op once firewalld
  #     takes over).
  #   - ufw has NO nixpkgs package at all (verified: no pkgs/by-name entry,
  #     no aliases.nix entry) — it's Ubuntu-specific tooling and was never
  #     going to be addable regardless of this decision.
  #   - iptables is still added below as a plain CLI package (legacy
  #     compat / manual rule inspection; nftables provides an iptables-compat
  #     shim anyway) since it was explicitly installed on Arch, but it is
  #     NOT wired up as the active firewall backend.

  # ── Tor ───────────────────────────────────────────────────────────────────
  # Arch had both `tor` (daemon) and client tools (proxychains-ng, torsocks)
  # installed, which implies they want an actual local SOCKS proxy for those
  # tools to route through — so the full daemon + client SOCKS port, not
  # just the package.
  services.tor = {
    enable = true;
    client.enable = true; # SocksPort 127.0.0.1:9050 for torsocks/proxychains-ng
  };
  # tor-browser-alpha-bin: nixpkgs only packages the stable channel (no alpha
  # variant exists) — already added as plain `tor-browser` in
  # home/modules/apps-browsers-comms.nix by a parallel migration slice, so
  # NOT duplicated here.

  # ── kdeconnect ────────────────────────────────────────────────────────────
  # `programs.kdeconnect.enable` (rather than a plain package) installs
  # kdePackages.kdeconnect-kde AND automatically opens the TCP+UDP port
  # range 1714-1764 in `networking.firewall` — which only works because we
  # kept the built-in firewall active above instead of switching to
  # firewalld.
  programs.kdeconnect.enable = true;

  # ── gvfs backends (gvfs-afc / -dnssd / -gphoto2 / -mtp / -nfs / -smb / -goa
  # / -onedrive / -wsdd) ──────────────────────────────────────────────────
  # desktop.nix already sets `services.gvfs.enable = true;` and lists a
  # plain `gvfs` package. Checked nixpkgs' gvfs derivation directly
  # (pkgs/by-name/gv/gvfs/package.nix): unlike Arch's split gvfs-* packages,
  # nixpkgs builds ONE gvfs derivation whose backends are selected by build
  # flags, and most of Arch's split packages are ALREADY compiled in by
  # default:
  #   - gvfs-afc     -> libimobiledevice (unconditional buildInput)
  #   - gvfs-dnssd   -> avahi            (unconditional buildInput)
  #   - gvfs-gphoto2 -> libgphoto2       (unconditional buildInput)
  #   - gvfs-nfs     -> libnfs           (unconditional buildInput)
  #   - gvfs-mtp     -> libmtp           (via `udevSupport`, default true on Linux)
  #   - gvfs-smb     -> samba            (via `udevSupport`, default true on Linux)
  # So all six of those need NO action — already covered by desktop.nix.
  #
  # gvfs-goa and gvfs-onedrive are DIFFERENT: they only get compiled in when
  # the derivation is built with `gnomeSupport = true` (default is false).
  # The idiomatic way to flip that is `services.gvfs.package =
  # pkgs.gvfs.override { gnomeSupport = true; };` — but desktop.nix ALSO
  # puts a plain, default-flags `gvfs` package directly into its
  # `environment.systemPackages`. Since `services.gvfs.nix` (the NixOS
  # module) independently adds `cfg.package` to `environment.systemPackages`
  # too, having BOTH the plain gvfs from desktop.nix and an overridden
  # gnomeSupport=true gvfs from here in the same systemPackages list would
  # be two differently-built derivations sharing the same output paths
  # (bin/gvfsd etc.) — a guaranteed `buildEnv` collision at build time. I was
  # told not to touch desktop.nix, so I deliberately did NOT add that
  # override here rather than risk breaking the build. FOLLOW-UP for
  # whoever wires the imports together: either (a) remove the bare `gvfs`
  # from desktop.nix's systemPackages and add
  # `services.gvfs.package = pkgs.gvfs.override { gnomeSupport = true; };`
  # here instead, or (b) accept no GOA-account / OneDrive gvfs mounting
  # (Nautilus/GOA-linked cloud storage — a narrow feature the user may not
  # need on a Hyprland desktop).
  #
  # gvfs-wsdd is NOT a gvfs backend at all — it's WS-Discovery (lets the file
  # manager see/be seen by Windows-style hosts without NetBIOS), and Arch
  # ships it as a companion `wsdd` daemon + gvfs glue package. nixpkgs has a
  # dedicated NixOS service for the daemon itself:
  services.samba-wsdd = {
    enable = true;
    discovery = true; # let this host see other WSD hosts on the network
    openFirewall = true; # punches the needed hole in networking.firewall
  };

  # ── Input remapping ───────────────────────────────────────────────────────
  services.input-remapper = {
    enable = true;
    # enableUdevRules left at its default (false): upstream has a known bug
    # with the udev-rules-driven hotplug path (nixpkgs module comment links
    # https://github.com/sezanzeb/input-remapper/issues/140). The daemon +
    # GUI (input-remapper-gtk) work fine without it; devices just need to be
    # plugged in before the service starts, or reattached once it's up.
  };

  # ── OOM / power / disk health daemons ─────────────────────────────────────
  services.earlyoom.enable = true;
  services.smartd.enable = true; # autodetect = true by default: SMART-monitors
                                  # every attached drive — a good fit for a
                                  # portable/USB boot drive.
  # services.smartd.devices intentionally NOT set here: this module is in
  # commonModules, so anything listed applies to BOTH hosts. The /dev/sda
  # entry it used to carry is the portable USB stick, which does not exist on
  # the internal-NVMe host — smartd treats a missing explicitly-listed device
  # as fatal ("Unable to register device /dev/sda (no Directive -d removable).
  # Exiting.", status 16) and failed on every laptop boot. It now lives in
  # hardware-configuration.nix, the portable host's own file.

  # ── VPN plugin wiring ─────────────────────────────────────────────────────
  # networkmanager-openvpn needs to go through networking.networkmanager's
  # own `plugins` option (not just environment.systemPackages) for
  # nm-applet/nmcli to actually recognize the OpenVPN VPN type. This is
  # additive to hardware-universal.nix's `networking.networkmanager.enable`
  # / `.wifi.backend` settings — no conflict.
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

  environment.systemPackages = with pkgs; [
    # ── Hardware / power / diagnostics ───────────────────────────────────
    acpi
    alsa-utils
    inxi
    hwinfo
    powertop
    smartmontools # smartctl CLI (services.smartd above uses this package too)
    ddcutil       # DDC/CI monitor control (brightness/input over the display cable)
    # nvtop: already added as `nvtopPackages.full` in modules/apps-gaming.nix
    # — not duplicated here.

    # ── Terminal / TUI toys & multiplexers ───────────────────────────────
    alacritty
    eza
    zellij
    asciiquarium
    cmatrix
    sl
    # peaclock: already added in home/modules/apps-desktop-shell.nix — not
    # duplicated here.

    # ── Filesystem tools ──────────────────────────────────────────────────
    dosfstools
    ntfs3g   # nixpkgs attribute for Arch's `ntfs-3g`
    exfatprogs
    udiskie
    unionfs-fuse
    # distrobox: already added in modules/apps-databases.nix (grouped with
    # its container-backend siblings podman/lazydocker/swtpm) — not
    # duplicated here.
    # NOTE re: unionfs-fuse — checked the "flutter-unionfs" reference in
    # memory (android-emulator-setup.md): that's an ad hoc Arch-side COW
    # mount (`/opt/flutter` RO + `~/.cache/flutter_local` RW) built at
    # runtime, not a Nix package/module reference, so there was nothing to
    # deduplicate against — this is a fresh addition.

    # ── Android / input tools ─────────────────────────────────────────────
    # scrcpy: already added in home/modules/apps-media.nix — not duplicated.
    # kdeconnect: handled via `programs.kdeconnect.enable` above, not a plain
    # package.
    input-remapper # GUI (input-remapper-gtk) + CLI; service enabled above
    evtest

    # ── Networking / diagnostics ──────────────────────────────────────────
    iptables       # CLI only — see firewall note above; NOT the active backend
    dnsmasq
    nmap
    mtr
    net-tools
    netcat-openbsd # nixpkgs renamed Arch's `openbsd-netcat` to this attribute
    iw
    wirelesstools  # nixpkgs attribute for Arch's `wireless_tools` (pname is
                    # "wireless-tools" internally; the top-level attr has no
                    # hyphen)
    wpa_supplicant # standalone CLI (wpa_cli/wpa_supplicant) for manual
                    # debugging — NetworkManager/iwd (hardware-universal.nix)
                    # already pull in their own copy transitively, but that
                    # doesn't put the CLI on $PATH for direct use

    # ── Security / pentesting tools ───────────────────────────────────────
    bettercap
    thc-hydra      # IMPORTANT: plain `pkgs.hydra` in nixpkgs is the unrelated
                    # Hydra CI/build system (hydra.nixos.org) — the actual
                    # THC-Hydra login-cracker (Arch's `hydra` package) lives
                    # at the `thc-hydra` attribute. Using `hydra` here would
                    # have silently installed the wrong tool.
    proxychains-ng
    torsocks

    # ── Remote access / transfer ──────────────────────────────────────────
    rclone
    # sshpass, keychain, putty: already added in
    # home/modules/apps-browsers-comms.nix — not duplicated here.
    proton-vpn     # nixpkgs renamed Arch's `proton-vpn-gtk-app` to this
                    # attribute (it's literally built from the
                    # ProtonVPN/proton-vpn-gtk-app upstream repo — verified
                    # in pkgs/by-name/pr/proton-vpn/linux.nix)
    # localsend: already added in home/modules/apps-browsers-comms.nix — not
    # duplicated here.

    # ── Calendar / CalDAV sync ─────────────────────────────────────────────
    gcalcli
    khal
    vdirsyncer

    # ── Wireless tools ─────────────────────────────────────────────────────
    wireguard-tools

    # ── Parental controls ──────────────────────────────────────────────────
    malcontent # ships the `malcontent-client` CLI; no separate GUI frontend
               # exists in this nixpkgs revision
  ];
}
