{ ... }:

# Runs dotfiles/hypr/scripts/BatteryNotify.sh every 2 minutes.
{
  systemd.user.services.battery-notify = {
    Unit = {
      Description = "Battery notification service";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.config/hypr/scripts/BatteryNotify.sh";
    };
  };

  systemd.user.timers.battery-notify = {
    Unit.Description = "Battery notification timer";
    Timer = {
      OnBootSec       = "1min";
      OnUnitActiveSec = "2min";
      Persistent      = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
