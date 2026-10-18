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
    nvtopPackages.full             # GPU monitor
  ];
}
