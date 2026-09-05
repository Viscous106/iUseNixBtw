{ pkgs, ... }:

{
  # ── Icon themes ─────────────────────────────────────────────────────────────
  # WHY THIS FILE EXISTS
  # home/qt6ct/qt6ct.conf carries `icon_theme=Flat-Remix-Blue-Dark` over from the
  # Arch dots, where flat-remix was installed as a separate package. It never was
  # here — before this file the only icon themes on the system were `hicolor` and
  # `locolor` (the Bibata entries under share/icons are CURSOR themes, which are a
  # different lookup entirely). Qt therefore resolved no icon at all and drew its
  # broken-image placeholder: the magenta-and-black checkerboard that showed up
  # for every folder in caelestia's file dialog.
  #
  # flat-remix-icon-theme ships Flat-Remix-Blue-Dark under exactly that name, so
  # installing it makes the existing qt6ct config work as written — no config
  # change needed, and qt5ct/GTK pick up the same theme.
  #
  # adwaita-icon-theme is the fallback layer. Flat-Remix declares
  #   Inherits=breeze-dark,elementary,gnome,hicolor
  # and of those only hicolor was present, so anything flat-remix does not define
  # itself fell through to nothing. Adwaita is what most GTK and Qt applications
  # assume exists and covers the generic names.
  home.packages = with pkgs; [
    flat-remix-icon-theme
    adwaita-icon-theme

    # ── GTK theme ─────────────────────────────────────────────────────────────
    # share/themes was empty: no GTK theme was installed at all, so GTK3 apps
    # (Thunar among them) fell back to GTK's built-in Adwaita. home/gtk-3.0/gtk.css
    # defines libadwaita-style variables — accent_color, window_bg_color,
    # headerbar_bg_color, sidebar_bg_color and friends — which built-in GTK3
    # Adwaita does not consume, so most of that palette was simply ignored and
    # Thunar came out half-styled.
    # adw-gtk3 is the GTK3 port of libadwaita's stylesheet and reads exactly those
    # names, so the existing gtk.css starts applying as it was written to.
    adw-gtk3
  ];
}
