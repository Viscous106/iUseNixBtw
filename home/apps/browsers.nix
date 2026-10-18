{ pkgs, ... }:

{
  # Browsers, comms and remote-desktop tools. Zen is in home/apps/zen.nix.
  home.packages = with pkgs; [
    # Browsers
    google-chrome  # no keyring here: Chromium browsers fall back to their own password store
    brave
    tor-browser
    opera           # own repack (pkgs/opera.nix); dropped from nixpkgs

    # Communications
    discord
    slack
    telegram-desktop
    zoom-us         # `zoom` is an unrelated interactive-fiction player
    localsend

    # Remote access
    freerdp         # RDP client
    putty
    sshpass
    keychain        # ssh-agent front-end
  ];
}
