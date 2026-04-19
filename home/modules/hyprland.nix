{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable        = true;
    systemd.enable = true;

    settings = {
      # Auto-detect monitor; works on any machine
      monitor = [ ",preferred,auto,auto" ];

      # Startup
      exec-once = [
        "waybar"
        "swww-daemon"
        "mako"
        "nm-applet --indicator"
        "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets"
      ];

      # ── Environment vars ───────────────────────────────────────────────
      env = [
        "XCURSOR_SIZE,24"
        "XCURSOR_THEME,Catppuccin-Mocha-Dark-Cursors"
        "QT_QPA_PLATFORM,wayland"
        "QT_QPA_PLATFORMTHEME,qt6ct"
        "GDK_BACKEND,wayland,x11"
        "SDL_VIDEODRIVER,wayland"
        "MOZ_ENABLE_WAYLAND,1"
        "EDITOR,nvim"
        "TERMINAL,kitty"
        "BROWSER,firefox"
      ];

      # ── General ────────────────────────────────────────────────────────
      general = {
        gaps_in     = 4;
        gaps_out    = 8;
        border_size = 2;
        "col.active_border"   = "rgba(89b4faff) rgba(cba6f7ff) 45deg";
        "col.inactive_border" = "rgba(313244ff)";
        layout      = "dwindle";
        allow_tearing = false;
      };

      # ── Decoration ─────────────────────────────────────────────────────
      decoration = {
        rounding    = 10;
        blur = {
          enabled   = true;
          size      = 5;
          passes    = 3;
          new_optimizations = true;
          ignore_opacity = true;
        };
        drop_shadow    = true;
        shadow_range   = 10;
        shadow_color   = "rgba(1a1a2eee)";
      };

      # ── Animations ─────────────────────────────────────────────────────
      animations = {
        enabled = true;
        bezier  = [
          "wind,   0.05, 0.9, 0.1, 1.05"
          "winIn,  0.1,  1.1, 0.1, 1.1"
          "winOut, 0.3,  -0.3, 0,  1"
          "liner,  1,    1,   1,   1"
        ];
        animation = [
          "windows,     1, 6,  wind,   slide"
          "windowsIn,   1, 6,  winIn,  slide"
          "windowsOut,  1, 5,  winOut, slide"
          "windowsMove, 1, 5,  wind,   slide"
          "border,      1, 1,  liner"
          "borderangle, 1, 30, liner,  loop"
          "fade,        1, 10, default"
          "workspaces,  1, 5,  wind"
        ];
      };

      # ── Input ──────────────────────────────────────────────────────────
      input = {
        kb_layout  = "us";
        kb_variant = "dvp";         # Programmer Dvorak
        kb_options = "caps:escape"; # Caps → Esc
        follow_mouse = 1;
        sensitivity  = 0;
        touchpad = {
          natural_scroll   = true;
          disable_while_typing = true;
          tap-to-click     = true;
        };
      };

      gestures = {
        workspace_swipe       = true;
        workspace_swipe_fingers = 3;
      };

      # ── Layouts ────────────────────────────────────────────────────────
      dwindle = {
        pseudotile     = true;
        preserve_split = true;
        smart_split    = true;
      };

      master = { new_is_master = true; };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo   = true;
        disable_splash_rendering = true;
        vfr = true;  # variable refresh rate — better on laptops
      };

      # ── Keybindings ────────────────────────────────────────────────────
      "$mod" = "SUPER";

      bind = [
        # Core
        "$mod, Return,      exec, kitty"
        "$mod, Q,           killactive"
        "$mod SHIFT, Q,     exit"
        "$mod, V,           togglefloating"
        "$mod, F,           fullscreen"
        "$mod, P,           pseudo"
        "$mod, J,           togglesplit"
        "$mod, R,           exec, wofi --show drun --allow-images"

        # Focus (vim keys)
        "$mod, H,           movefocus, l"
        "$mod, L,           movefocus, r"
        "$mod, K,           movefocus, u"
        "$mod, J,           movefocus, d"
        "$mod, left,        movefocus, l"
        "$mod, right,       movefocus, r"
        "$mod, up,          movefocus, u"
        "$mod, down,        movefocus, d"

        # Move windows
        "$mod SHIFT, H,     movewindow, l"
        "$mod SHIFT, L,     movewindow, r"
        "$mod SHIFT, K,     movewindow, u"
        "$mod SHIFT, J,     movewindow, d"

        # Workspaces
        "$mod, 1,           workspace, 1"
        "$mod, 2,           workspace, 2"
        "$mod, 3,           workspace, 3"
        "$mod, 4,           workspace, 4"
        "$mod, 5,           workspace, 5"
        "$mod, 6,           workspace, 6"
        "$mod, 7,           workspace, 7"
        "$mod, 8,           workspace, 8"
        "$mod, 9,           workspace, 9"
        "$mod, 0,           workspace, 10"

        "$mod SHIFT, 1,     movetoworkspace, 1"
        "$mod SHIFT, 2,     movetoworkspace, 2"
        "$mod SHIFT, 3,     movetoworkspace, 3"
        "$mod SHIFT, 4,     movetoworkspace, 4"
        "$mod SHIFT, 5,     movetoworkspace, 5"
        "$mod SHIFT, 6,     movetoworkspace, 6"
        "$mod SHIFT, 7,     movetoworkspace, 7"
        "$mod SHIFT, 8,     movetoworkspace, 8"
        "$mod SHIFT, 9,     movetoworkspace, 9"
        "$mod SHIFT, 0,     movetoworkspace, 10"

        # Scroll through workspaces
        "$mod, mouse_down,  workspace, e+1"
        "$mod, mouse_up,    workspace, e-1"

        # Screenshot
        ", Print,           exec, grim ~/Pictures/screenshot-$(date +%s).png"
        "SHIFT, Print,      exec, grim -g \"$(slurp)\" ~/Pictures/screenshot-$(date +%s).png"

        # Media keys
        ", XF86AudioRaiseVolume,  exec, pamixer -i 5"
        ", XF86AudioLowerVolume,  exec, pamixer -d 5"
        ", XF86AudioMute,         exec, pamixer -t"
        ", XF86AudioPlay,         exec, playerctl play-pause"
        ", XF86AudioNext,         exec, playerctl next"
        ", XF86AudioPrev,         exec, playerctl previous"
        ", XF86MonBrightnessUp,   exec, brightnessctl set +10%"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"

        # Lock
        "$mod, Delete,      exec, hyprlock"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # ── Window rules ───────────────────────────────────────────────────
      windowrule = [
        "float, class:^(nm-connection-editor)$"
        "float, class:^(org.gnome.Nautilus)$"
        "float, title:^(Picture-in-Picture)$"
        "size 800 600, class:^(nm-connection-editor)$"
      ];
    };
  };
}
