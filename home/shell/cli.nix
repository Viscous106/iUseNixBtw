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
    pass        # GPG password store; Proton Mail Bridge keeps its login here
  ];
}
