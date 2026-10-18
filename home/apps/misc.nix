{ pkgs, ... }:

{
  # Editors, office suite, journal and misc utilities.
  home.packages = with pkgs; [
    obsidian
    # Editors
    code-cursor     # Cursor editor
    mousepad        # GTK text editor
    nano

    # Office / spelling
    libreoffice-stable  # `libreoffice-fresh` is now a warning alias
    hunspellDicts.en_US

    # Journal
    tui-journal     # `tjournal`; aliased as `scrible` in home/shell/zsh.nix

    # Networking / testing utilities
    speedtest-cli   # not `speedtest`, an unrelated GTK4 app
    prettyping
  ];
}
