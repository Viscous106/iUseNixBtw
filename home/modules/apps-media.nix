{ config, pkgs, ... }:

{
  # ── Media, graphics & audio tools ──────────────────────────────────────────
  # Ported from Arch's explicitly-installed package list. See report for
  # anything skipped (no nixpkgs equivalent) and redundancy notes.
  home.packages = with pkgs; [
    # Streaming / recording
    obs-studio          # screen recording & streaming
    streamlink          # pull live streams into a local player
    mov-cli             # terminal media-streaming scraper/browser
    ani-cli             # terminal anime streaming scraper

    # Downloaders
    yt-dlp              # video/audio downloader
    spotdl              # Spotify track downloader

    # mpv companions
    mpvpaper            # use mpv as a live-wallpaper renderer
    mpvScripts.mpris    # MPRIS media-control plugin for mpv
                         # NOTE: installing the script package alone doesn't
                         # wire it into mpv; whoever edits modules/mpv.nix
                         # still needs to add it via programs.mpv.scripts or
                         # symlink it into the mpv scripts dir.

    # Wallpaper (see redundancy note in report — awww/swww is the daemon
    # actually driving wallpapers on this system; swaybg was still an
    # explicit Arch install so it's included here too)
    swaybg

    # PipeWire graph/patch tools
    qpwgraph             # PipeWire patchbay GUI
    # NOTE: helvum was requested but has been REMOVED from nixpkgs
    # (unmaintained upstream, vulnerable dependency — the `helvum` attr
    # now throws). Upstream nixpkgs points to `crosspipe` as a
    # replacement; not added automatically, see report.

    # Audio/video CLI utilities
    sox                  # audio processing swiss-army-knife
    ffmpegthumbnailer    # video thumbnail generator (file manager previews)
    exiftool             # perl-image-exiftool -> nixpkgs attr is `exiftool`

    # Screenshots / input-visualization
    silicon              # code screenshot tool
    showmethekey         # on-screen keypress visualizer

    # Webcam
    guvcview             # webcam viewer/capture utility

    # DLNA/UPnP media sharing
    rygel                # UPnP/DLNA media server
    grilo-plugins        # media discovery plugins (used by Rygel/GNOME media apps)

    # GNOME Circle apps
    decibels             # audio player
    showtime             # video player
    loupe                # image viewer
    papers               # document viewer (formerly Evince/Papers)
    simple-scan          # scanner front-end
    snapshot             # webcam/photo booth app
    sushi                # Nautilus quick-preview (GNOME Files)

    # PDF viewer
    zathura              # nixpkgs' `zathura` already bundles the mupdf PDF
                          # backend by default, no extra plugin package needed

    # PulseAudio prefs GUI
    paprefs

    # Fonts
    font-awesome         # otf-font-awesome -> closest nixpkgs equivalent;
                          # ships the OTF Font Awesome glyphs (currently v7,
                          # Arch's build is v6 — check icon coverage if used
                          # for a specific glyph set)

    # Color temperature (f.lux-style)
    gammastep

    # Android screen mirroring
    scrcpy

    # Terminal toy
    pokemon-colorscripts
  ];
}
