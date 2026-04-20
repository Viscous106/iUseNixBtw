{ config, pkgs, lib, ... }:

{
  # ── keyd — kernel-level key remapping ─────────────────────────────────────
  # Ported from your Arch /etc/keyd/default.conf
  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = [ "*" ];   # apply to all keyboards

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
          esc          = "layer(capslock_layer)";

          # Alt keys activate meta layer
          leftalt      = "layer(meta)";
          rightalt     = "layer(meta)";
        };

        # ── Mouse layer (hold Space then use hjkl to scroll) ────────────────
        "mouse_layer:C" = {
          capslock = "leftmouse";
          enter    = "rightmouse";
          h        = "wheel(left)";
          j        = "wheel(down)";
          k        = "wheel(up)";
          l        = "wheel(right)";
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
    layout  = "us";
    variant = "dvp";   # Programmer Dvorak, full system
    options = "";      # keyd handles caps/mod remapping at kernel level
  };
}
