{ config, pkgs, ... }:

{
  # ── Wayland/Hyprland desktop-shell ecosystem + theming/archive/utility apps ─
  # Ported from the Arch package list. Everything here is a plain nixpkgs
  # attribute verified against the pinned nixpkgs source tree — nothing
  # invented. See notes below for the handful of Arch packages that either
  # don't exist in nixpkgs or map to a differently-named attribute.
  home.packages = with pkgs; [

    # ── Astal (libastal-*) + shells built on it ────────────────────────────
    # nixpkgs ships a native `astal` package SET (pkgs/development/libraries
    # /astal), so none of this needs a separate flake input — it's plain
    # nixpkgs. Aylur's `ags` v2 already depends on astal internally.
    ags                       # aylurs-gtk-shell (v2.3.0, built on astal — NOT the legacy `ags_1`/v1.8.2)
    quickshell                # quickshell
    astal.astal3              # libastal-git      (core GTK3 astal library)
    astal.astal4              # libastal-4-git    (core GTK4 astal library)
    astal.io                  # libastal-io-git
    astal.battery             # libastal-battery-git
    astal.bluetooth           # libastal-bluetooth-git
    astal.hyprland            # libastal-hyprland-git
    astal.network             # libastal-network-git
    astal.notifd              # libastal-notifd-git
    astal.tray                # libastal-tray-git
    astal.wireplumber         # libastal-wireplumber-git

    # ── Hypr* / wlr* utilities ──────────────────────────────────────────────
    hyprpicker                # color picker
    warpd                     # keyboard-driven pointer warping
    wev                       # wayland event viewer
    wf-recorder               # screen recorder
    wlrctl                    # wlr-layer-shell/output control CLI
    wtype                     # xdotool-type equivalent for wayland
    wmctrl                    # X11 window control (used by some scripts/apps)

    # ── Theming ─────────────────────────────────────────────────────────────
    wallust                   # colorscheme generator (pywal-alternative)
    # gtk-engine-murrine + gtk2 removed: gtk-engine-murrine dropped from
    # nixpkgs (depended on GTK2, which nixpkgs no longer packages); gtk2 was
    # only kept here to support it, so both go together.
    libsForQt5.qtstyleplugin-kvantum   # Kvantum (Qt5 style engine + manager)
    qt6Packages.qtstyleplugin-kvantum  # Kvantum (Qt6 style engine + manager)

    # ── X11 clipboard/session compat (still used under XWayland) ───────────
    xclip                     # X11 clipboard CLI
    xhost                     # xorg-xhost — X server access control

    # ── Launchers/dialogs ────────────────────────────────────────────────────
    dmenu                     # minimal dynamic menu
    yad                       # yet-another-dialog (GTK dialog boxes for scripts)

    # ── Archive managers / Thunar integration ───────────────────────────────
    kdePackages.ark           # ark — KDE archive manager
    xarchiver                 # lightweight GTK archive manager
    thunar-archive-plugin     # Thunar right-click archive integration
    unrar                     # rar/cbr extraction backend for the above

    # ── Disk / calculator / docs / accessibility ────────────────────────────
    gparted                   # partition editor
    gnome-calculator          # GNOME calculator
    qalculate-gtk             # scientific/unit calculator
    yelp                      # GNOME help viewer
    gnome-tecla               # GNOME "Tecla" keyboard-shortcut viewer
                               # (NOT `tecla` — that nixpkgs attr is an
                               # unrelated Caltech C readline library)
    orca                      # screen reader
    appmenu-glib-translator   # global-menu (appmenu) translator for GTK apps

    # ── Misc utilities ───────────────────────────────────────────────────────
    arandr                    # GUI frontend for xrandr
    peaclock                  # terminal clock/timer/stopwatch
  ];
}
