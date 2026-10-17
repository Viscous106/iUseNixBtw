{ config, pkgs, ... }:

{
  # ── Wayland/Hyprland desktop-shell ecosystem + theming/archive/utility apps ─
  # Ported from the Arch package list. Everything here is a plain nixpkgs
  # attribute verified against the pinned nixpkgs source tree — nothing
  # invented. See notes below for the handful of Arch packages that either
  # don't exist in nixpkgs or map to a differently-named attribute.
  home.packages = with pkgs; [

    # ── Hypr* / wlr* utilities ──────────────────────────────────────────────
    hyprpicker                # color picker
    warpd                     # keyboard-driven pointer warping
    wev                       # wayland event viewer
    wf-recorder               # screen recorder
    wlrctl                    # wlr-layer-shell/output control CLI
    wmctrl                    # X11 window control (used by some scripts/apps)

    # ── Theming ─────────────────────────────────────────────────────────────
    # gtk-engine-murrine + gtk2 removed: gtk-engine-murrine dropped from
    # nixpkgs (depended on GTK2, which nixpkgs no longer packages); gtk2 was
    # only kept here to support it, so both go together.
    libsForQt5.qtstyleplugin-kvantum   # Kvantum (Qt5 style engine + manager)
    qt6Packages.qtstyleplugin-kvantum  # Kvantum (Qt6 style engine + manager)

    # ── X11 clipboard/session compat (still used under XWayland) ───────────
    xclip                     # X11 clipboard CLI
    xhost                     # xorg-xhost — X server access control

    # ── Archive managers / Thunar integration ───────────────────────────────
    kdePackages.ark           # ark — KDE archive manager
    xarchiver                 # lightweight GTK archive manager
    # thunar-archive-plugin moved to programs.thunar.plugins in
    # modules/desktop.nix — as a loose package it was installed but never loaded.
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
