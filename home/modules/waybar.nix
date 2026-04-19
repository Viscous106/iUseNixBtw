{ config, pkgs, ... }:

{
  programs.waybar = {
    enable        = true;
    systemd.enable = true;

    settings = [{
      layer    = "top";
      position = "top";
      height   = 36;
      spacing  = 4;

      modules-left   = [ "hyprland/workspaces" "hyprland/submap" "hyprland/window" ];
      modules-center = [ "clock" ];
      modules-right  = [
        "pulseaudio" "network" "bluetooth"
        "battery" "cpu" "memory" "temperature"
        "backlight" "tray"
      ];

      "hyprland/workspaces" = {
        format      = "{icon}";
        on-click    = "activate";
        format-icons = {
          "1"  = "";
          "2"  = "";
          "3"  = "󰭹";
          "4"  = "";
          "5"  = "";
          "6"  = "󰎄";
          "urgent"  = "";
          "focused" = "";
          "default" = "";
        };
        sort-by-number = true;
      };

      "hyprland/window" = {
        format    = "{}";
        max-length = 40;
        separate-outputs = true;
      };

      clock = {
        timezone        = "Asia/Kolkata";
        format          = "  {:%H:%M}";
        format-alt      = "  {:%A, %B %d, %Y}";
        tooltip-format  = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };

      battery = {
        states          = { warning = 30; critical = 15; };
        format          = "{icon}  {capacity}%";
        format-charging = "󰂄  {capacity}%";
        format-plugged  = "  {capacity}%";
        format-icons    = [ "" "" "" "" "" ];
        on-click        = "";
      };

      network = {
        format-wifi         = "󰤨  {essid} ({signalStrength}%)";
        format-ethernet     = "󰈀  {ipaddr}";
        format-linked       = "󰈀  {ifname} (No IP)";
        format-disconnected = "󰤭  Offline";
        tooltip-format      = "{ifname}: {ipaddr}\n{gwaddr}";
        on-click            = "nm-connection-editor";
      };

      bluetooth = {
        format          = "󰂯";
        format-connected = "󰂱  {device_alias}";
        format-connected-battery = "󰂱  {device_alias} {device_battery_percentage}%";
        tooltip-format  = "{controller_alias}\t{controller_address}\n{num_connections} connected";
        on-click        = "blueman-manager";
      };

      pulseaudio = {
        format          = "{icon}  {volume}%";
        format-bluetooth = "󰂰  {volume}%";
        format-muted    = "󰝟  Muted";
        format-icons    = { default = [ "󰕿" "󰖀" "󰕾" ]; headphone = "󰋋"; headset = "󰋎"; };
        on-click        = "pavucontrol";
        on-click-right  = "pamixer -t";
        scroll-step     = 5;
      };

      cpu = {
        format   = "󰻠  {usage}%";
        interval = 2;
        on-click = "kitty -e btop";
      };

      memory = {
        format   = "󰍛  {percentage}%";
        interval = 5;
        on-click = "kitty -e btop";
        tooltip-format = "{used:0.1f}G / {total:0.1f}G";
      };

      temperature = {
        thermal-zone      = 0;
        critical-threshold = 80;
        format            = "  {temperatureC}°C";
        format-critical   = "  {temperatureC}°C";
      };

      backlight = {
        format      = "{icon}  {percent}%";
        format-icons = [ "󰃞" "󰃟" "󰃠" ];
        on-scroll-up   = "brightnessctl set +5%";
        on-scroll-down = "brightnessctl set 5%-";
      };

      tray = {
        spacing      = 8;
        icon-size    = 16;
      };
    }];

    style = ''
      @import url("file://${config.xdg.configHome}/waybar/colors.css");

      * {
        border        : none;
        border-radius : 0;
        font-family   : "JetBrainsMono Nerd Font", "Inter";
        font-size     : 13px;
        min-height    : 0;
      }

      window#waybar {
        background-color : rgba(30, 30, 46, 0.90);
        color            : @text;
        transition-property : background-color;
        transition-duration : 0.5s;
      }

      window#waybar.hidden { opacity: 0.2; }

      #workspaces button {
        padding   : 0 8px;
        background: transparent;
        color     : @subtext0;
        border    : none;
      }

      #workspaces button:hover {
        background : rgba(137, 180, 250, 0.15);
        color      : @lavender;
        box-shadow : inset 0 -3px @lavender;
      }

      #workspaces button.active {
        color      : @lavender;
        box-shadow : inset 0 -3px @lavender;
        font-weight: bold;
      }

      #workspaces button.urgent {
        color : @red;
      }

      #mode {
        background-color : @surface0;
        border-bottom    : 3px solid @text;
        padding          : 0 8px;
      }

      #clock, #battery, #cpu, #memory, #disk, #temperature,
      #backlight, #network, #pulseaudio, #bluetooth,
      #custom-media, #tray, #mode, #mpd {
        padding : 0 12px;
        color   : @text;
      }

      #battery.charging, #battery.plugged { color: @green; }
      #battery.warning:not(.charging)     { color: @yellow; }
      #battery.critical:not(.charging)    { color: @red;    animation-name: blink; animation-duration: 0.5s; animation-timing-function: linear; animation-iteration-count: infinite; animation-direction: alternate; }

      #cpu       { color: @blue;    }
      #memory    { color: @mauve;   }
      #clock     { color: @lavender; font-weight: bold; }
      #network.disconnected { color: @red; }

      @keyframes blink { to { color: @surface0; } }
    '';
  };

  # Catppuccin Mocha colors for Waybar
  xdg.configFile."waybar/colors.css".text = ''
    @define-color rosewater #f5e0dc;
    @define-color flamingo  #f2cdcd;
    @define-color pink      #f5c2e7;
    @define-color mauve     #cba6f7;
    @define-color red       #f38ba8;
    @define-color maroon    #eba0ac;
    @define-color peach     #fab387;
    @define-color yellow    #f9e2af;
    @define-color green     #a6e3a1;
    @define-color teal      #94e2d5;
    @define-color sky       #89dceb;
    @define-color sapphire  #74c7ec;
    @define-color blue      #89b4fa;
    @define-color lavender  #b4befe;
    @define-color text      #cdd6f4;
    @define-color subtext1  #bac2de;
    @define-color subtext0  #a6adc8;
    @define-color overlay2  #9399b2;
    @define-color overlay1  #7f849c;
    @define-color overlay0  #6c7086;
    @define-color surface2  #585b70;
    @define-color surface1  #45475a;
    @define-color surface0  #313244;
    @define-color base      #1e1e2e;
    @define-color mantle    #181825;
    @define-color crust     #11111b;
  '';
}
