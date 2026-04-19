{ ... }:

{
  # ── TTY console keyboard ───────────────────────────────────────────────────
  # "dvp" = Programmer Dvorak in the Linux console keymap database
  console = {
    keyMap     = "dvp";
    font       = "Lat2-Terminus16";
    earlySetup = true;   # applies in initrd so LUKS prompts use correct layout
  };

  # ── Xkb (consumed by Hyprland/Wayland via libxkbcommon) ───────────────────
  services.xserver.xkb = {
    layout  = "us";
    variant = "dvp";          # Programmer Dvorak
    options = "caps:escape";  # Caps Lock → Escape
  };
}
