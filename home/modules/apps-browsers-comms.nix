{ pkgs, ... }:

{
  # ── Browsers, comms apps, and remote-desktop/VNC tools ─────────────────────
  # Migrated from the Arch install's explicitly-installed package list.
  # NOTE: zen-browser is provided via the `zen-browser` flake input
  # (see flake.nix + home/modules/zen.nix) — not duplicated here.
  home.packages = with pkgs; [
    # Browsers
    firefox
    google-chrome
    brave           # AUR was brave-bin; nixpkgs ships the browser directly as `brave`
    epiphany        # GNOME Web
    tor-browser     # AUR was tor-browser-alpha-bin; nixpkgs only packages the stable
                    # channel (currently 15.0.9) — no alpha variant is available.
    # NOTE: `opera-beta` (AUR) has NO nixpkgs equivalent — the `opera` attribute
    # was removed from nixpkgs on 2025-05-19 ("removed due to lack of
    # maintenance"); nixpkgs/pkgs/top-level/aliases.nix now makes it a throw.

    # Communications
    telegram-desktop
    zoom-us         # AUR `zoom` maps to nixpkgs `zoom-us`; nixpkgs's own `zoom`
                    # attribute is an unrelated Z-Code/interactive-fiction player.
    # NOTE: `instagram-cli` has NO nixpkgs equivalent — not present anywhere in
    # the nixpkgs tree (niche/AUR-only), verified by source search.

    # Webcam / screen sharing
    # NOTE: `iriunwebcam-bin` has NO nixpkgs equivalent — not present anywhere
    # in the nixpkgs tree (niche/AUR-only, proprietary), verified by source search.

    localsend

    # Remote desktop / VNC
    tigervnc        # provides both the VNC client and server in one package
    x11vnc
    wayvnc
    kdePackages.krdc # KDE's RDP/VNC client; krdc-xfreerdp (AUR) covered by
                     # krdc + freerdp below (krdc uses freerdp as its RDP backend)
    freerdp
    putty
    sshpass
    keychain        # ssh-agent front-end
  ];
}
