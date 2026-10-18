{ pkgs, ... }:

{
  home.packages = [ pkgs.tmux ];

  # Declared here so tmux-continuum doesn't install its own unit, which kills every session on restart.
  # oneshot + RemainAfterExit: the guarded save runs only on a real stop and never writes an empty save.
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
