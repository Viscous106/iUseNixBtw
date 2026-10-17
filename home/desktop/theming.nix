{ pkgs, ... }:

{
  # GTK / Qt configs themselves are linked from home/dotfiles.nix.
  home.packages = with pkgs; [
    libsForQt5.qt5ct
    nwg-look
    flat-remix-icon-theme
    adwaita-icon-theme
    adw-gtk3
  ];

  home.pointerCursor = {
    enable     = true;
    package    = pkgs.bibata-cursors;
    name       = "Bibata-Modern-Classic";
    size       = 20;
    gtk.enable = true;
    x11.enable = true;
  };
}
