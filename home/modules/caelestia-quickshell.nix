{ inputs, ... }:

{
  # ── Caelestia shell ─────────────────────────────────────────────────────────
  # Quickshell-based desktop shell (bar, notifications, launcher, lock, OSDs) —
  # the replacement for waybar + swaync. Upstream ships its own Home Manager
  # module at nix/hm-module.nix, exposed as homeManagerModules.default; it
  # defines programs.caelestia and puts `caelestia-shell` on home.packages.
  #
  # `inputs` is in scope here because flake.nix passes
  # home-manager.extraSpecialArgs = { inherit inputs; }.
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  programs.caelestia = {
    enable = true;

    # The caelestia CLI drives the running shell over IPC (wallpaper and colour
    # scheme switching, toggling panels from keybinds). The module's default
    # package is already the `with-cli` variant, so the shell bundles it; this
    # additionally puts the standalone `caelestia` binary on PATH.
    cli.enable = true;

    # Launch from Hyprland's startup_apps.lua rather than the systemd user unit.
    # Upstream's unit is WantedBy = config.wayland.systemd.target, which resolves
    # to graphical-session.target — and this session never reaches it. Hyprland
    # is started directly here (no uwsm), so that target sits inactive and the
    # unit would never fire. Verified: `systemctl --user is-active
    # graphical-session.target` -> inactive. exec_cmd also matches how waybar was
    # launched, keeping one startup mechanism for the session.
    systemd.enable = false;
  };
}
