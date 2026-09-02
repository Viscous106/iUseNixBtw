{ pkgs, ... }:

# ── ydotoold — matches ~/.config/systemd/user/ydotoold.service on Arch,
# which was enabled (default.target.wants/ydotoold.service). Needed by
# hyprwhspr's paste-injection and by kanata-adjacent input scripts
# (toggle_warpd.sh etc.) for synthetic input on Wayland.
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
