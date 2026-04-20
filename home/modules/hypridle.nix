{ config, pkgs, ... }:

{
  # ── Hypridle — idle daemon configuration ───────────────────────────────────
  services.hypridle = {
    enable = true;

    settings = {
      general = {
        lock_cmd            = "pidof hyprlock || hyprlock";
        unlock_cmd          = "killall -q hyprlock";
        before_sleep_cmd    = "loginctl lock-session";
        after_sleep_cmd     = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
      };

      listener = [
        # Turn off screen fast when already locked
        {
          timeout    = 30;
          on-timeout = "pidof hyprlock && hyprctl dispatch dpms off";
          on-resume  = "pidof hyprlock && hyprctl dispatch dpms on";
        }
        # Dim + turn off screen after 5 min
        {
          timeout    = 300;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume  = "hyprctl dispatch dpms on";
        }
        # Lock after 3 min idle
        {
          timeout    = 180;
          on-timeout = "loginctl lock-session";
        }
      ];
    };
  };

  # ── Hyprlock — screen locker configuration ─────────────────────────────────
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor         = true;
        grace               = 5;
        no_fade_in          = false;
      };

      background = [{
        monitor     = "";
        path        = "screenshot";
        blur_size   = 6;
        blur_passes = 3;
        noise       = 0.0117;
        contrast    = 0.8917;
        brightness  = 0.8;
        vibrancy    = 0.1696;
        vibrancy_darkness = 0.0;
      }];

      input-field = [{
        monitor        = "";
        size           = "250, 50";
        outline_thickness = 2;
        dots_size      = 0.33;
        dots_spacing   = 0.15;
        dots_center    = false;
        outer_color    = "rgb(595959)";
        inner_color    = "rgb(1e1e2e)";
        font_color     = "rgb(cdd6f4)";
        fade_on_empty  = true;
        placeholder_text = ''<i>Password...</i>'';
        hide_input     = false;
        check_color    = "rgb(a6e3a1)";
        fail_color     = "rgb(f38ba8)";
        fail_text      = ''<i>$FAIL <b>($ATTEMPTS)</b></i>'';
        position       = "0, -120";
        halign         = "center";
        valign         = "center";
      }];

      label = [
        # Clock
        {
          monitor   = "";
          text      = ''cmd[update:1000] echo "<b><big>$(date +"%H:%M")</big></b>"'';
          color     = "rgba(cda6f7ff)";
          font_size = 90;
          font_family = "JetBrainsMono Nerd Font Bold";
          position  = "0, -300";
          halign    = "center";
          valign    = "top";
        }
        # Date
        {
          monitor   = "";
          text      = ''cmd[update:1000] echo "$(date +"%A, %B %d")"'';
          color     = "rgba(cdd6f4ff)";
          font_size = 20;
          font_family = "JetBrainsMono Nerd Font";
          position  = "0, -400";
          halign    = "center";
          valign    = "top";
        }
      ];
    };
  };
}
