{ config, pkgs, ... }:

{
  # Desktop utilities, theming, archive and accessibility apps.
  home.packages = with pkgs; [

    # ── Hypr* / wlr* utilities ──────────────────────────────────────────────
    hyprpicker                # color picker
    warpd                     # keyboard-driven pointer warping
    wev                       # wayland event viewer
    wf-recorder               # screen recorder
    wlrctl                    # wlr-layer-shell/output control CLI
    wmctrl                    # X11 window control (used by some scripts/apps)

    # ── Theming ─────────────────────────────────────────────────────────────
    libsForQt5.qtstyleplugin-kvantum   # Kvantum (Qt5 style engine + manager)
    qt6Packages.qtstyleplugin-kvantum  # Kvantum (Qt6 style engine + manager)

    # ── X11 clipboard/session compat (still used under XWayland) ───────────
    xclip                     # X11 clipboard CLI
    xhost                     # X server access control

    # ── Archive managers / Thunar integration ───────────────────────────────
    kdePackages.ark           # KDE archive manager
    xarchiver                 # lightweight GTK archive manager
    unrar                     # rar/cbr extraction backend for the above

    # ── Disk / calculator / docs / accessibility ────────────────────────────
    gparted                   # partition editor
    gnome-calculator          # GNOME calculator
    qalculate-gtk             # scientific/unit calculator
    yelp                      # GNOME help viewer
    gnome-tecla               # keyboard-layout viewer (`tecla` is unrelated)
    orca                      # screen reader
    appmenu-glib-translator   # global-menu (appmenu) translator for GTK apps

    # ── Misc utilities ───────────────────────────────────────────────────────
    arandr                    # GUI frontend for xrandr
    peaclock                  # terminal clock/timer/stopwatch
  ];
}
