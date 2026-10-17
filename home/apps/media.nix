{ config, pkgs, ... }:

{
  # Media, graphics and audio tools.
  home.packages = with pkgs; [
    (mpv.override { scripts = [ mpvScripts.mpris ]; })  # media keys via MPRIS
    cava
    # Streaming / recording
    obs-studio          # screen recording & streaming
    streamlink          # pull live streams into a local player

    # Downloaders
    yt-dlp              # video/audio downloader
    spotdl              # Spotify track downloader

    # mpv companions
    mpvpaper            # use mpv as a live-wallpaper renderer

    # Spotify + spicetify
    spotify
    spicetify-cli

    # PipeWire graph/patch tools
    qpwgraph             # PipeWire patchbay GUI

    # Audio/video CLI utilities
    sox                  # audio processing swiss-army-knife
    ffmpegthumbnailer    # video thumbnail generator (file manager previews)
    exiftool

    # Screenshots / input-visualization
    silicon              # code screenshot tool
    showmethekey         # on-screen keypress visualizer

    # DLNA/UPnP media sharing
    rygel                # UPnP/DLNA media server
    grilo-plugins        # media discovery plugins (used by Rygel/GNOME media apps)

    # GNOME Circle apps
    decibels             # audio player
    showtime             # video player
    loupe                # image viewer
    papers               # document viewer
    simple-scan          # scanner front-end
    snapshot             # webcam/photo booth app
    sushi                # Nautilus quick-preview (GNOME Files)

    # PDF viewer
    zathura              # bundles the mupdf backend

    # PulseAudio prefs GUI
    paprefs

    # Color temperature (f.lux-style)
    gammastep

    # Android screen mirroring
    scrcpy
  ];
}
