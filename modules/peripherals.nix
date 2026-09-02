{ config, pkgs, ... }:

# ── Peripherals not covered elsewhere: kanata (keyboard remapper) + the
# uinput udev rule it and ydotool both need. Ported from Arch's AUR
# `kanata-git` (config at ~/.config/kanata/config.kbd) and the udev rule at
# /etc/udev/rules.d/99-uinput.rules.
{
  # ── kanata ────────────────────────────────────────────────────────────────
  # configFile points straight at the vendored file (live-editable, same
  # pattern as the home-manager mkOutOfStoreSymlink dotfiles) rather than
  # letting the module regenerate a config from devices/config/extraDefCfg —
  # Arch's config.kbd is a complete file already.
  # Disabled: keyd (modules/keyboard.nix) is the remapper now, and both grab
  # the same physical keyboard (i8042). kanata's only binding — caps tap=esc,
  # hold=lctl — is already covered by keyd's `capslock = overload(alt, esc)`,
  # with Ctrl-hold living on tab/backslash there. Set back to true (and drop
  # keyd) to swap remappers; running both double-remaps caps.
  services.kanata = {
    enable = false;
    keyboards.default.configFile = "/persist/nixos-config/home/kanata/config.kbd";
  };

  # services.kanata.enable already sets hardware.uinput.enable = true, which
  # grants its own "uinput" group access to /dev/uinput. Arch instead granted
  # the "input" group (99-uinput.rules below) and viscous is already a member
  # of "input" (configuration.nix) — kept as an additional rule so ydotoold
  # (which isn't in the "uinput" group) also gets /dev/uinput access, exactly
  # matching Arch's actual rule.
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
