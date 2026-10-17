{ config, pkgs, inputs, ... }:

{
  # ── Caelestia shell ─────────────────────────────────────────────────────────
  # Quickshell desktop shell (bar, notifications, launcher, lock, OSDs).
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  programs.caelestia.package =
    (inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.with-cli).overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        # Sidebar/dashboard survive focus loss (wl-kbptr); no config option exists.
        ../../pkgs/caelestia-panel-focus-grab.patch
        # vimKeybinds next/previous on Alt instead of Ctrl; launcher search needs bare letters.
        ../../pkgs/caelestia-alt-navigation.patch
        # "battery" bar entry above the clock; upstream has no DelegateChoice for it.
        ../../pkgs/caelestia-battery-entry.patch
      ];
    });

  programs.caelestia = {
    enable = true;

    cli.enable = true; # standalone `caelestia` IPC CLI on PATH

    # Launched from dotfiles/hypr/lua/startup_apps.lua instead, so the session
    # has one startup mechanism.
    systemd.enable = false;

    settings = {
      # Default is ~/Pictures/Wallpapers (capital W); scanned recursively.
      paths.wallpaperDir = "~/Pictures/wallpapers";

      # Sole idle manager (no hypridle). Plain suspend: suspend-then-hibernate
      # needs a resume offset for the btrfs swapfile, which is not configured.
      general.idle = {
        lockBeforeSleep  = true;
        inhibitWhenAudio = true;
        timeouts = [
          { timeout = 180; idleAction = "lock"; }
          { timeout = 300; idleAction = "dpms off"; returnAction = "dpms on"; }
          { timeout = 600; idleAction = [ "suspend" ]; }
        ];
      };

      # Hovering the top edge slid the dashboard over windows' title controls.
      # Still on SUPER+SHIFT+E / SUPER+ALT+B.
      dashboard.showOnHover = false;

      # awww/mpvpaper own the background layer (video support); set colours
      # with `caelestia scheme set` since the wallpaper no longer drives them.
      background.wallpaperEnabled = false;

      # persistent forces the bar visible, breaking the SUPER+SHIFT+T toggle.
      # Shown once at login by dotfiles/hypr/scripts/CaelestiaBarInit.sh.
      bar.persistent = false;
      bar.showOnHover = false;

      # Upstream defaults plus "battery" (needs the Bar.qml patch above). The
      # list replaces the default rather than merging, so it is restated in full.
      bar.entries = [
        { id = "logo";         enabled = true; }
        { id = "workspaces";   enabled = true; }
        { id = "spacer";       enabled = true; }
        { id = "activeWindow"; enabled = true; }
        { id = "spacer";       enabled = true; }
        { id = "tray";         enabled = true; }
        { id = "battery";      enabled = true; }
        { id = "clock";        enabled = true; }
        { id = "statusIcons";  enabled = true; }
        { id = "power";        enabled = true; }
      ];

      # Battery off here so it is not drawn twice; otherwise upstream defaults.
      bar.statusIcons = [
        { id = "lockStatus"; enabled = true; }
        { id = "audio";      enabled = false; }
        { id = "microphone"; enabled = false; }
        { id = "kbLayout";   enabled = false; }
        { id = "network";    enabled = true; }
        { id = "bluetooth";  enabled = true; }
        { id = "battery";    enabled = false; }
      ];

      # Keyboard-drivable without wl-kbptr (navigation remapped to Alt above).
      launcher.vimKeybinds = true;
      session.vimKeybinds = true;
    };
  };

  # The CLI ignores shell.json's paths.wallpaperDir and reads this instead.
  home.sessionVariables.CAELESTIA_WALLPAPERS_DIR = "${config.home.homeDirectory}/Pictures/wallpapers";

  home.packages = [
    # `caelestia clipboard` (SUPER+V) shells out to `fuzzel --dmenu`.
    pkgs.fuzzel
  ];
}
