{ config, pkgs, inputs, ... }:

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

    settings = {
      # Caelestia's default is ~/Pictures/Wallpapers (capital W); this library is
      # ~/Pictures/wallpapers, and btrfs is case-sensitive — so it found nothing
      # and fell back to its own bundled assets/wallpaper.webp. That is why the
      # desktop background changed when the shell first started.
      # FileSystemModel is `recursive: true`, so the per-theme subdirectories
      # (favs, scene, animeGirls, …) are all picked up from this one path.
      paths.wallpaperDir = "~/Pictures/wallpapers";

      # Upstream defaults dashboard.showOnHover to true, which makes the whole
      # top edge of the screen a hover trigger: moving the pointer up to reach a
      # window's own top-right controls slides the dashboard down over them, so
      # the click lands on the dashboard instead. The drawers surface is
      # full-screen (namespace caelestia-drawers, 1920x1080 at layer "top") and
      # its input mask grows to the panel's height once the panel opens, so this
      # is not recoverable by clicking faster. The dashboard is still on
      # SUPER+SHIFT+E and SUPER+ALT+B; only the hover trigger goes away.
      dashboard.showOnHover = false;

      # Caelestia must not paint a wallpaper: qs-wallpaper-picker applies through
      # awww (images, with transitions) and mpvpaper (video), and both draw on
      # the background layer. With caelestia also painting there, the two fight
      # over the same surface. awww/mpvpaper wins ownership because it is the
      # only one of the two that can do video at all.
      # Consequence: the wallpaper no longer drives caelestia's Material colour
      # scheme. Use `caelestia scheme set …` by hand, or set
      # enableDynamicColors in the picker's Settings.qml to hand that job to
      # matugen (already on the picker's PATH).
      background.wallpaperEnabled = false;
    };
  };

  # The CLI does not read shell.json. caelestia/utils/paths.py resolves the
  # library as os.getenv("CAELESTIA_WALLPAPERS_DIR", ~/Pictures/Wallpapers) —
  # a completely separate mechanism from the shell's paths.wallpaperDir above.
  # Without this, `caelestia wallpaper -r` dies with "No valid wallpapers found"
  # while the shell's own picker happily lists all 274 images.
  home.sessionVariables.CAELESTIA_WALLPAPERS_DIR = "${config.home.homeDirectory}/Pictures/wallpapers";

  # ── qs-wallpaper-picker ─────────────────────────────────────────────────────
  # Fast keyboard-first Quickshell picker on SUPER+W, handling images and video.
  # See pkgs/qs-wallpaper-picker.nix. It reads its library from QS_WALLPAPER_DIR
  # (upstream default is ~/Wallpapers, which is not where this library lives).
  home.packages = [ pkgs.qs-wallpaper-picker ];
  home.sessionVariables.QS_WALLPAPER_DIR = "${config.home.homeDirectory}/Pictures/wallpapers";
}
