{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable        = true;
    systemd.enable = true;

    settings = {
      # ── Monitor ────────────────────────────────────────────────────────────
      # Auto-detect; on your laptop this picks up eDP-1 automatically.
      # Override on boot via: hyprctl keyword monitor "eDP-1, 1920x1080@144, auto, 1"
      monitor = [ ",preferred,auto,1" ];

      # ── Variables ──────────────────────────────────────────────────────────
      "$mainMod"   = "SUPER";
      "$term"      = "kitty";
      "$files"     = "thunar";
      "$edit"      = "nvim";

      # ── Environment ────────────────────────────────────────────────────────
      env = [
        # Toolkit backends
        "GDK_BACKEND,wayland,x11,*"
        "QT_QPA_PLATFORM,wayland;xcb"
        "CLUTTER_BACKEND,wayland"

        # XDG
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"

        # QT
        "QT_AUTO_SCREEN_SCALE_FACTOR,1"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "QT_QUICK_CONTROLS_STYLE,org.hyprland.style"

        # Scale fixes
        "GDK_SCALE,1"
        "QT_SCALE_FACTOR,1"

        # Firefox / Electron
        "MOZ_ENABLE_WAYLAND,1"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"

        # App defaults
        "EDITOR,nvim"
        "TERMINAL,kitty"
        "BROWSER,firefox"

        # Cursor
        "XCURSOR_THEME,Catppuccin-Mocha-Dark-Cursors"
        "XCURSOR_SIZE,24"
      ];

      # ── Startup ────────────────────────────────────────────────────────────
      exec-once = [
        # Wayland environment propagation (needed before portals)
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"

        # Wallpaper daemon
        "swww-daemon --format xrgb"

        # Bar
        "waybar"

        # Idle / lock daemon
        "hypridle"

        # Notifications
        "swaync"

        # Polkit
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"

        # Network / Bluetooth trays
        "nm-applet --indicator"
        "blueman-applet"

        # Clipboard manager
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      # ── General ────────────────────────────────────────────────────────────
      general = {
        border_size     = 2;
        gaps_in         = 2;
        gaps_out        = 4;
        "col.active_border"   = "rgba(595959ff)";
        "col.inactive_border" = "rgba(333333ff)";
        layout          = "dwindle";
        resize_on_border = true;
        allow_tearing   = false;
      };

      # ── Decoration ─────────────────────────────────────────────────────────
      decoration = {
        rounding           = 10;
        active_opacity     = 1.0;
        inactive_opacity   = 0.9;
        fullscreen_opacity = 1.0;
        dim_inactive       = true;
        dim_strength       = 0.1;
        dim_special        = 0.8;

        shadow = {
          enabled       = true;
          range         = 3;
          render_power  = 1;
          color         = "rgba(595959ff)";
          color_inactive = "rgba(333333ff)";
        };

        blur = {
          enabled          = true;
          size             = 6;
          passes           = 2;
          ignore_opacity   = true;
          new_optimizations = true;
          special          = true;
          popups           = true;
        };
      };

      # ── Animations ─────────────────────────────────────────────────────────
      animations = {
        enabled = true;
        bezier = [
          "wind,       0.05, 0.9,  0.1,  1.05"
          "winIn,      0.1,  1.1,  0.1,  1.1"
          "winOut,     0.3, -0.3,  0,    1"
          "liner,      1,    1,    1,    1"
          "overshot,   0.05, 0.9,  0.1,  1.05"
          "smoothOut,  0.5,  0,    0.99, 0.99"
          "smoothIn,   0.5, -0.5,  0.68, 1.5"
        ];
        animation = [
          "windows,       1, 6, wind,      slide"
          "windowsIn,     1, 5, winIn,     slide"
          "windowsOut,    1, 3, smoothOut, slide"
          "windowsMove,   1, 5, wind,      slide"
          "border,        1, 1, liner"
          "borderangle,   1, 180, liner,   loop"
          "fade,          1, 3, smoothOut"
          "workspaces,    1, 5, overshot"
          "workspacesIn,  1, 5, winIn,     slide"
          "workspacesOut, 1, 5, winOut,    slide"
        ];
      };

      # ── Input ──────────────────────────────────────────────────────────────
      input = {
        # Single Programmer Dvorak layout — no QWERTY anywhere
        kb_layout   = "us";
        kb_variant  = "dvp";
        kb_options  = "";
        repeat_rate  = 50;
        repeat_delay = 300;
        sensitivity  = 0;
        numlock_by_default = true;
        left_handed  = false;
        follow_mouse = 1;
        float_switch_override_focus = false;

        touchpad = {
          disable_while_typing    = true;
          natural_scroll          = true;
          clickfinger_behavior    = false;
          middle_button_emulation = false;
          "tap-to-click"          = true;
          drag_lock               = false;
        };
      };

      # ── Gestures ───────────────────────────────────────────────────────────
      gestures = {
        workspace_swipe_distance         = 500;
        workspace_swipe_invert           = true;
        workspace_swipe_min_speed_to_force = 30;
        workspace_swipe_cancel_ratio     = 0.5;
        workspace_swipe_create_new       = true;
        workspace_swipe_forever          = true;
      };

      # ── Layouts ────────────────────────────────────────────────────────────
      dwindle = {
        pseudotile           = true;
        preserve_split       = true;
        special_scale_factor = 0.8;
      };

      master = {
        new_status = "master";
        new_on_top = 1;
        mfact      = 0.5;
      };

      # ── Misc ───────────────────────────────────────────────────────────────
      misc = {
        disable_hyprland_logo   = true;
        disable_splash_rendering = true;
        vfr                     = true;
        vrr                     = 2;
        mouse_move_enables_dpms = true;
        enable_swallow          = false;
        swallow_regex           = "^(kitty)$";
        focus_on_activate       = false;
        initial_workspace_tracking = 0;
        middle_click_paste      = false;
        enable_anr_dialog       = true;
        anr_missed_pings        = 15;
        allow_session_lock_restore = true;
      };

      binds = {
        workspace_back_and_forth = true;
        allow_workspace_cycles   = true;
        pass_mouse_when_bound    = false;
      };

      xwayland = {
        enabled           = true;
        force_zero_scaling = true;
      };

      cursor = {
        sync_gsettings_theme    = true;
        no_hardware_cursors     = 1;
        enable_hyprcursor       = true;
        warp_on_change_workspace = 2;
        no_warps                = true;
      };

      render.direct_scanout = 0;

      # ── Keybindings ────────────────────────────────────────────────────────
      bind = [
        # Core apps
        "$mainMod, Return,      exec, $term"
        "$mainMod, E,           exec, $files"
        "$mainMod, Q,           killactive"
        "$mainMod SHIFT, Q,     exit"
        "$mainMod, V,           togglefloating"
        "$mainMod, F,           fullscreen"
        "$mainMod, P,           pseudo"
        "$mainMod, J,           togglesplit"
        "$mainMod, R,           exec, wofi --show drun --allow-images"
        "$mainMod, backspace,   exec, hyprlock"

        # Clipboard history
        "$mainMod, C,           exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"

        # Focus (vim keys + arrows)
        "$mainMod, H,           movefocus, l"
        "$mainMod, L,           movefocus, r"
        "$mainMod, K,           movefocus, u"
        "$mainMod, J,           movefocus, d"
        "$mainMod, left,        movefocus, l"
        "$mainMod, right,       movefocus, r"
        "$mainMod, up,          movefocus, u"
        "$mainMod, down,        movefocus, d"

        # Move windows (CTRL + arrow)
        "$mainMod CTRL, left,   movewindow, l"
        "$mainMod CTRL, right,  movewindow, r"
        "$mainMod CTRL, up,     movewindow, u"
        "$mainMod CTRL, down,   movewindow, d"

        # Swap windows (ALT + arrow)
        "$mainMod ALT, left,    swapwindow, l"
        "$mainMod ALT, right,   swapwindow, r"
        "$mainMod ALT, up,      swapwindow, u"
        "$mainMod ALT, down,    swapwindow, d"

        # Move windows (vim)
        "$mainMod SHIFT, H,     movewindow, l"
        "$mainMod SHIFT, L,     movewindow, r"
        "$mainMod SHIFT, K,     movewindow, u"
        "$mainMod SHIFT, J,     movewindow, d"

        # Workspaces
        "$mainMod, 1,           workspace, 1"
        "$mainMod, 2,           workspace, 2"
        "$mainMod, 3,           workspace, 3"
        "$mainMod, 4,           workspace, 4"
        "$mainMod, 5,           workspace, 5"
        "$mainMod, 6,           workspace, 6"
        "$mainMod, 7,           workspace, 7"
        "$mainMod, 8,           workspace, 8"
        "$mainMod, 9,           workspace, 9"
        "$mainMod, 0,           workspace, 10"

        "$mainMod SHIFT, 1,     movetoworkspace, 1"
        "$mainMod SHIFT, 2,     movetoworkspace, 2"
        "$mainMod SHIFT, 3,     movetoworkspace, 3"
        "$mainMod SHIFT, 4,     movetoworkspace, 4"
        "$mainMod SHIFT, 5,     movetoworkspace, 5"
        "$mainMod SHIFT, 6,     movetoworkspace, 6"
        "$mainMod SHIFT, 7,     movetoworkspace, 7"
        "$mainMod SHIFT, 8,     movetoworkspace, 8"
        "$mainMod SHIFT, 9,     movetoworkspace, 9"
        "$mainMod SHIFT, 0,     movetoworkspace, 10"

        # Screenshot
        ", Print,               exec, grim ~/Pictures/screenshot-$(date +%s).png"
        "SHIFT, Print,          exec, grim -g \"$(slurp)\" ~/Pictures/screenshot-$(date +%s).png"
        "$mainMod CTRL, S,      exec, grim -g \"$(slurp)\" - | swappy -f -"

        # Volume (pamixer — simple direct binds)
        ", XF86AudioRaiseVolume,  exec, pamixer -i 5"
        ", XF86AudioLowerVolume,  exec, pamixer -d 5"
        ", XF86AudioMute,         exec, pamixer -t"
        ", XF86AudioMicMute,      exec, pamixer --default-source -t"
        ", XF86AudioPlay,         exec, playerctl play-pause"
        ", XF86AudioPause,        exec, playerctl play-pause"
        ", XF86AudioNext,         exec, playerctl next"
        ", XF86AudioPrev,         exec, playerctl previous"
        ", XF86AudioStop,         exec, playerctl stop"

        # Brightness
        ", XF86MonBrightnessUp,   exec, brightnessctl set +10%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"

        # Suspend on sleep key
        ", XF86Sleep,             exec, systemctl suspend"


        # Pavucontrol
        "$mainMod ALT, S,       exec, pavucontrol"

        # Toggle opacity
        "$mainMod CTRL, O,      exec, hyprctl setprop active opacity toggle"

        # Scroll through workspaces with mouse wheel on bar
        "$mainMod, mouse_down,  workspace, e+1"
        "$mainMod, mouse_up,    workspace, e-1"
      ];

      # Repeating binds (held down)
      binde = [
        ", XF86AudioRaiseVolume,  exec, pamixer -i 5"
        ", XF86AudioLowerVolume,  exec, pamixer -d 5"
        ", XF86MonBrightnessUp,   exec, brightnessctl set +10%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # ── Window Rules ───────────────────────────────────────────────────────
      windowrule = [
        # Terminals
        "opacity 0.9 0.7, match:class ^(kitty)$"

        # Float
        "float on, match:class ^(nm-connection-editor)$"
        "float on, match:class ^(pavucontrol|org.pulseaudio.pavucontrol)$"
        "float on, match:class ^(blueman-manager)$"
        "float on, match:class ^(mpv|vlc)$"
        "float on, match:class ^([Qq]alculate-gtk)$"
        "float on, match:title ^(Picture-in-Picture)$"
        "float on, match:title ^(Authentication Required)$"
        "float on, match:title ^(Save As)$"
        "float on, match:title ^(Add Folder to Workspace)$"
        "float on, match:title (Open Files)"

        # Center
        "center on, match:class ^(pavucontrol|org.pulseaudio.pavucontrol)$"
        "center on, match:title ^(Authentication Required)$"
        "center on, match:title ^(Save As)$"
        "center on, match:title ^(Add Folder to Workspace)$"

        # Size
        "size 70% 70%, match:class ^(pavucontrol|org.pulseaudio.pavucontrol)$"
        "size 70% 60%, match:title ^(Save As)$"
        "size 70% 60%, match:title ^(Add Folder to Workspace)$"

        # PiP
        "pin on, match:title ^(Picture-in-Picture)$"
        "move 72% 7%, match:title ^(Picture-in-Picture)$"
        "keep_aspect_ratio on, match:title ^(Picture-in-Picture)$"
        "opacity 0.95 0.75, match:title ^(Picture-in-Picture)$"

        # Video: no blur, full opacity
        "no_blur on, match:class ^([Mm]pv|vlc)$"
        "opacity 1 override 1 override, match:class ^([Mm]pv|vlc)$"

        # JetBrains - prevent focus stealing
        "no_initial_focus on, match:class ^(jetbrains-.*)$"
      ];

      # Layer rules
      layerrule = [
        "blur on, match:namespace rofi"
        "xray on, match:namespace rofi"
        "blur on, match:namespace notifications"
        "xray on, match:namespace notifications"
      ];
    };
  };
}
