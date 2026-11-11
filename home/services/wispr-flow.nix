{ pkgs, ... }:

# Dictation daemon: --hidden keeps the Hub closed; the status pill and Wispr's own hotkey do the work.
{
  home.packages = [ pkgs.wispr-flow ];

  systemd.user.services.wispr-flow = {
    Unit = {
      Description = "Wispr Flow dictation";
      After       = [ "graphical-session.target" ];
      PartOf      = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart  = "${pkgs.wispr-flow}/bin/wispr-flow --hidden";
      Restart    = "on-failure";   # a clean quit from the tray stays quit
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
