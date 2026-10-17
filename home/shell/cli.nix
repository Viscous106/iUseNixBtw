{ pkgs, ... }:

{
  home.packages = with pkgs; [
    fd
    ripgrep
    bat
    chafa
    psmisc      # killall
    yazi
    fastfetch
    gh
    ghgrab
    nix-tree
    antigen
  ];
}
