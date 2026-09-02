{ ... }:

# ── Battery notification timer — ported from Arch's
# ~/.config/systemd/user/battery-notify.{service,timer} (enabled there).
# Runs the already-vendored home/hypr/scripts/BatteryNotify.sh.
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
