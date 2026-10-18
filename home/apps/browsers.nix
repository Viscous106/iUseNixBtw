{ pkgs, ... }:

{
  # Browsers, comms and remote-desktop tools. Zen is in home/apps/zen.nix.
  home.packages = with pkgs; [
    # Browsers
    firefox
    google-chrome  # no keyring here: Chromium browsers fall back to their own password store
    brave
    epiphany        # GNOME Web
    tor-browser
    opera           # own repack (pkgs/opera.nix); dropped from nixpkgs

    # Communications
    discord
    slack
    telegram-desktop
    zoom-us         # `zoom` is an unrelated interactive-fiction player
    localsend

    # Remote desktop / VNC
    tigervnc        # VNC client + server
    x11vnc
    wayvnc
    kdePackages.krdc # RDP/VNC client; uses freerdp for RDP
    freerdp
    putty
    sshpass
    keychain        # ssh-agent front-end
  ];
}
