# wallpaper-picker: QML lives in dotfiles/quickshell (no rebuild). hyprctl isn't a runtimeInput:
# the wrapper prefixes PATH, so the session's hyprctl is used.
{
  lib,
  writeShellApplication,
  quickshell,
  awww,
  mpvpaper,
  ffmpegthumbnailer,
  jq,
  socat,
  procps,
  coreutils,
  qt6,
}:

writeShellApplication {
  name = "wallpaper-picker";

  runtimeInputs = [
    quickshell
    awww
    mpvpaper
    ffmpegthumbnailer
    jq
    socat         # audio-follow.sh: Hyprland event stream + mpv IPC
    procps        # pkill, used when swapping between image and video
    coreutils
  ];

  text = ''
    CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/wallpaper-picker"

    if [ "''${1-}" = "--restore" ]; then
      # Restore does not need Qt at all — go straight to the shared apply path
      # so login stays fast and cannot diverge from what the UI does.
      exec "$CONFIG_DIR/apply.sh" --restore
    fi

    if [ ! -d "$CONFIG_DIR" ]; then
      echo "wallpaper-picker: $CONFIG_DIR missing (is the home-manager module enabled?)" >&2
      exit 1
    fi

    # Qt's WebP plugin is in qtimageformats, off the default plugin path; without it .webp cards render
    # blank. Exported here because writeShellApplication has no makeWrapper.
    export QT_PLUGIN_PATH="${qt6.qtimageformats}/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"

    # Pin to the monitor focused at launch, before the overlay can shift focus; empty lets apply.sh decide.
    WP_OUTPUT="$(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null | head -1 || true)"
    export WP_OUTPUT

    exec quickshell -p "$CONFIG_DIR"
  '';

  meta = {
    description = "Skewed-carousel Quickshell wallpaper selector";
    mainProgram = "wallpaper-picker";
    platforms = lib.platforms.linux;
  };
}
