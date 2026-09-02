{ config, pkgs, lib, ... }:

{
  # ── Rofi launcher ─────────────────────────────────────────────────────────
  # Live-editable: edit /persist/nixos-config/home/rofi/ without rebuilding
  xdg.configFile."rofi".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/rofi";

  # ── Swaync notification center ────────────────────────────────────────────
  xdg.configFile."swaync".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/swaync";

  # swaync and hypridle are both launched solely via exec-once
  # (startup_apps.lua), matching the original Arch/JaKooLit design (no
  # systemd unit involved for either, on Arch). Both packages ship their own
  # bundled systemd --user unit (share/systemd/user/{swaync,hypridle}.service)
  # that gets auto-discovered purely because the package sits in home.packages
  # / environment.systemPackages -- independent of services.hypridle.enable
  # (set false in hyprland.nix) or any home-manager option for swaync (there
  # is none). If graphical-session.target is ever activated (now that
  # wayland.windowManager.hyprland.systemd.enable is false, it normally
  # isn't), these bundled units would race the exec-once instances: whichever
  # starts second dies (swaync errors "An instance ... is already running!")
  # and crash-loops to start-limit-hit. Mask both (symlink to /dev/null) the
  # same way `systemctl --user mask` would, via an activation script --
  # home-manager's xdg.configFile can't express a literal "/dev/null" source
  # (Nix's pure-evaluation mode forbids reading absolute host paths at eval
  # time), and systemd.user.services has no generic mask-an-external-unit
  # option.
  home.activation.maskDuplicateSessionUnits = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/systemd/user"
    ln -sf /dev/null "$HOME/.config/systemd/user/swaync.service"
    ln -sf /dev/null "$HOME/.config/systemd/user/hypridle.service"
  '';

  # ── Tmux ──────────────────────────────────────────────────────────────────
  xdg.configFile."tmux".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/tmux";

  # ── Tmuxifier — vendored verbatim from Arch (not a nixpkgs package) ────────
  xdg.configFile."tmuxifier".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/tmuxifier";

  # ── keyd app.conf — per-app passthrough rules for keyd-application-mapper ─
  xdg.configFile."keyd/app.conf".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/keyd/app.conf";

  # ── Neovim — real kickstart.nvim tree vendored from Arch ──────────────────
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/nvim";

  # ── kanata — config.kbd read directly by services.kanata (modules/
  # peripherals.nix); symlinked here too so `~/.config/kanata` matches Arch.
  xdg.configFile."kanata".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/kanata";

  # ── OpenRGB (GUI settings + effect) — Arch has both a capitalised data
  # dir and a lowercase one (custom shader effects) side by side.
  xdg.configFile."OpenRGB".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/OpenRGB";
  xdg.configFile."openrgb".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/openrgb";

  # ── OBS Studio ──────────────────────────────────────────────────────────
  xdg.configFile."obs-studio".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/obs-studio";

  # ── Spicetify (just the Marketplace custom app — Arch never actually set
  # up config-xpui.ini/Themes, so there's no active theme to port) ─────────
  xdg.configFile."spicetify".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/spicetify";

  # ── scaler-content — a personal project, vendored as the live working
  # copy (matches WorkingDirectory=%h/Viscous/scaler-content in
  # home/modules/scaler.nix); secrets live at /persist/secrets/scaler-listen-env.
  home.file."Viscous/scaler-content".source = config.lib.file.mkOutOfStoreSymlink
    "/persist/nixos-config/home/scaler-content";
}
