{ pkgs, ... }:

{
  # Browsers, comms and remote-desktop tools. Zen is in home/apps/zen.nix.
  home.packages = with pkgs; [
    # Browsers
    google-chrome  # no keyring here: Chromium browsers fall back to their own password store
    brave
    opera           # own repack (pkgs/opera.nix); dropped from nixpkgs

    # Communications
    discord
    slack
    telegram-desktop
    localsend

    # Remote access
    sshpass
    keychain        # ssh-agent front-end
  ];
}
