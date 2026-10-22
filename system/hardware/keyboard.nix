{ config, pkgs, lib, ... }:

{
  # ── keyd — kernel-level key remapping ─────────────────────────────────────
  # keyd-application-mapper must be on PATH for the exec-once that starts it.
  environment.systemPackages = [ pkgs.keyd ];

  # Don't create a "keyd" group: keyd then calls setgid(), which the nixpkgs
  # unit's sandbox blocks, and it crash-loops.

  # keyd exits 15 on SIGTERM; treat it as clean so rebuilds don't mark it failed.
  systemd.services.keyd.serviceConfig.SuccessExitStatus = "15";

  services.keyd = {
    enable = true;

    keyboards.default = {
      # ids from `keyd monitor`; the trailing hash disambiguates shared vendor:product ids.
      ids = [ "*" ];

      settings = {
        # ── Main layer ──────────────────────────────────────────────────────
        main = {
          tab          = "overload(control, tab)";
          backslash    = "overload(control, backslash)";
          capslock     = "overload(alt, esc)";
          enter        = "overload(alt, enter)";
          space        = "overload(mouse_layer, space)";

          leftshift    = "oneshot(shift)";
          rightshift   = "oneshot(shift)";

          esc          = "overload(capslock_layer, esc)";

          leftalt      = "layer(meta)";
          rightalt     = "layer(meta)";
        };

        # ── Mouse layer (hold Space for clicks + directional keys) ─────────
        "mouse_layer:C" = {
          capslock = "leftmouse";
          enter    = "rightmouse";
          j        = "left";
          p        = "right";
          v        = "up";
          c        = "down";
          b        = "space";
        };

        # ── Capslock layer (physical Esc + modifier) ─────────────────────────
        "capslock_layer:C" = {
          delete = "f24";      # Esc+Delete → F24 (can bind in Hyprland)
          shift  = "capslock"; # Esc+Shift → actual Capslock toggle
        };
      };
    };

    # Wispr Flow's virtual keyboard sends US key positions (its paste is the US V key);
    # move each letter to its Dvorak position so its Ctrl+V/C land as Ctrl+v/c.
    keyboards.wispr-flow = {
      ids = [ "1234:5678:0626f29d" ];
      settings.main = {
        b = "n"; c = "i"; d = "h"; e = "d"; f = "y"; g = "u"; h = "j"; i = "g";
        j = "c"; k = "v"; l = "p"; n = "l"; o = "s"; p = "r"; q = "x"; r = "o";
        s = "semicolon"; t = "k"; u = "f"; v = "dot"; w = "comma"; x = "b";
        y = "t"; z = "slash";
      };
    };
  };

  # ── TTY console keyboard ──────────────────────────────────────────────────
  console = {
    useXkbConfig = true;  # derives keymap from services.xserver.xkb below
    font       = "Lat2-Terminus16";
    earlySetup = true;   # active in initrd so LUKS/root prompts use dvp
  };

  # ── Xkb (consumed by Hyprland/Wayland via libxkbcommon) ───────────────────────
  services.xserver.xkb = {
    layout  = "us,us";  # dvp primary, plain us fallback — matches live kb_layout
    variant = "dvp,";   # switch with hyprctl switchxkblayout all next
    options = "";      # keyd handles caps/mod remapping at kernel level
  };

  # /dev/uinput for the input group (keyd, Wispr Flow, input-remapper).
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660"
  '';
}
