{ pkgs, ... }:

# Synthetic input on Wayland, for hyprwhspr paste-injection and input scripts
# (toggle_warpd.sh etc.).
{
  home.packages = [ pkgs.ydotool ];

  systemd.user.services.ydotoold = {
    Unit.Description = "ydotool daemon";
    Service = {
      ExecStart  = "${pkgs.ydotool}/bin/ydotoold";
      Restart    = "always";
      RestartSec = 1;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
