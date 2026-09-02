{ config, pkgs, lib, ... }:

{
  # ── keyd — kernel-level key remapping ─────────────────────────────────────
  # Ported from your Arch /etc/keyd/default.conf
  # keyd-application-mapper needs to be on PATH for the exec-once that starts it
  environment.systemPackages = [ pkgs.keyd ];

  # NOTE: do NOT create a "keyd" group here. keyd only warns when the group is
  # missing, but if it exists it calls setgid() — which the nixpkgs unit's
  # sandbox blocks (`SystemCallFilter=~@privileged`, and CAP_SETGID is not in
  # its CapabilityBoundingSet). keyd then dies with `setgid: Operation not
  # permitted`, exit 255, and hits the restart limit. Creating the group only
  # buys nicer perms on /run/keyd/keyd.socket for keyd-application-mapper;
  # that needs the unit's sandbox loosened too, so leave both alone.

  # keyd exits with the signal number (15) on SIGTERM, so every `systemctl
  # stop` — including the restart in a nixos-rebuild switch — leaves the unit
  # in `failed`. Treat 15 as a clean exit.
  systemd.services.keyd.serviceConfig.SuccessExitStatus = "15";

  services.keyd = {
    enable = true;

    keyboards.default = {
      # "*" minus the virtual devices that "*" would otherwise sweep in:
      # ids come from `keyd monitor`. Both the real keyboard and kanata's
      # virtual output report 0001:0001, so the trailing hash is required.
      ids = [
        "*"
        "-2333:6666:e7fb73a9"   # ydotoold virtual device — keyd would re-remap
                                # hyprwhspr's injected keystrokes
        "-0000:0000:39ecd0ee"   # sof-glkrt5682max Headset Jack — not a keyboard
      ];

      settings = {
        # ── Main layer ──────────────────────────────────────────────────────
        main = {
          # Hold = Ctrl, tap = Tab
          tab          = "overload(control, tab)";
          # Hold = Ctrl, tap = Backslash
          backslash    = "overload(control, backslash)";
          # Hold = Alt, tap = Esc
          capslock     = "overload(alt, esc)";
          # Hold = Alt, tap = Enter
          enter        = "overload(alt, enter)";
          # Hold = mouse_layer, tap = Space
          space        = "overload(mouse_layer, space)";

          # Oneshot shift (tap+release is a single shifted keypress)
          leftshift    = "oneshot(shift)";
          rightshift   = "oneshot(shift)";

          # Esc activates capslock_layer (for physical Esc key)
          esc          = "overload(capslock_layer, esc)";

          # Alt keys activate meta layer
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
  };

  # ── TTY console keyboard ──────────────────────────────────────────────────
  # dvp = Programmer Dvorak — applies to ALL TTYs including root login
  console = {
    useXkbConfig = true;  # derives keymap from services.xserver.xkb above
    font       = "Lat2-Terminus16";
    earlySetup = true;   # active in initrd so LUKS/root prompts use dvp
  };

  # ── Xkb (consumed by Hyprland/Wayland via libxkbcommon) ───────────────────────
  # Single layout — no QWERTY fallback anywhere
  services.xserver.xkb = {
    layout  = "us,us";  # dvp primary, plain us fallback — matches live kb_layout
    variant = "dvp,";   # switch with hyprctl switchxkblayout all next
    options = "";      # keyd handles caps/mod remapping at kernel level
  };
}
