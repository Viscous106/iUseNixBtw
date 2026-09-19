{ config, pkgs, ... }:

# ── Peripherals not covered elsewhere: the uinput udev rule ydotool needs,
# ported from Arch's /etc/udev/rules.d/99-uinput.rules, plus OpenRGB.
#
# kanata was removed: it was carried over from Arch's AUR `kanata-git` but sat
# at enable = false the whole time, because keyd (modules/keyboard.nix) is the
# remapper here and both grab the same physical keyboard (i8042). Its only
# binding — caps tap=esc, hold=lctl — is already covered by keyd's
# `capslock = overload(alt, esc)`, with Ctrl-hold on tab/backslash. To swap
# remappers, add services.kanata back and drop keyd; running both double-remaps
# caps.
{
  # hardware.uinput.enable comes from services.keyd (verified: it is the sole
  # definition of that option in this config), which grants the "uinput" group
  # access to /dev/uinput. Arch instead granted the "input" group, and viscous
  # is already a member of "input" (configuration.nix) — kept as an additional
  # rule so ydotoold (which is not in the "uinput" group) also gets /dev/uinput
  # access, exactly matching Arch's actual rule.
  #
  # This used to credit services.kanata with enabling uinput. That was never
  # true while kanata sat disabled — its hardware.uinput.enable = true lives
  # inside the module's `config = lib.mkIf cfg.enable` block.
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660"
  '';

  # ── OpenRGB ───────────────────────────────────────────────────────────────
  # Arch just runs the OpenRGB GUI app manually (no systemd service was
  # enabled for it) — so this stays a plain package + vendored user config
  # (home/modules/extras.nix), not services.hardware.openrgb (which runs it
  # as an always-on system server with a different profile-storage model).
  environment.systemPackages = [ pkgs.openrgb ];
}
