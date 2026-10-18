{ config, pkgs, ... }:

{
  # Media, graphics and audio tools.
  home.packages = with pkgs; [
    (mpv.override { scripts = [ mpvScripts.mpris ]; })  # media keys via MPRIS
    mpvpaper           # video wallpapers (wallpaper-picker)
    cava
    yt-dlp
    loupe              # image viewer
    zathura            # PDF viewer
    gammastep          # night light

    # CLI helpers
    sox
    ffmpegthumbnailer  # video thumbnails in the file manager
    exiftool
    silicon            # code screenshots
    showmethekey       # on-screen keypress visualizer
  ];
}
