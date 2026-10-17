{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    gamescopeSession.enable      = true;
    remotePlay.openFirewall      = true;
    dedicatedServer.openFirewall = false;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  environment.systemPackages = with pkgs; [
    wineWow64Packages.stagingFull  # 32+64-bit wine (plain wine-staging is 32-bit only)
    winetricks
    lutris
    nvtopPackages.full             # GPU monitor
  ];
}
