{ pkgs, ... }:

{
  home.packages = [ pkgs.tmux ];

  # Declared here so tmux-continuum never writes its own tmux.service, whose
  # KillMode/ExecStop kill every session on any unit restart.
  # oneshot + RemainAfterExit: ExecStop (save) runs only on a real stop, not
  # when the server exits by itself. Saving through the guarded wrapper avoids
  # writing an empty save that the next restore would load.
  systemd.user.services.tmux = {
    Unit = {
      Description   = "tmux default session (detached)";
      Documentation = "man:tmux(1)";
    };
    Service = {
      Type            = "oneshot";
      RemainAfterExit = true;
      Environment     = [ "DISPLAY=:0" "TMUX_BIN=${pkgs.tmux}/bin/tmux" ];
      ExecStart       = "%h/.config/tmux/tmux-service-start.sh";    # idempotent
      ExecStop        = "%h/.config/tmux/tmux-save-if-running.sh";
      KillMode        = "none";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
