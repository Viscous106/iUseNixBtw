# wallpaper-picker: QML stays live in dotfiles/quickshell/wallpaper-picker (not
# the store) so it can change without a rebuild. hyprctl is intentionally not a
# runtimeInput: the wrapper prefixes PATH, so the session's hyprctl is used.
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

    # Qt's WebP (and other extra-format) image plugins live in qtimageformats,
    # not in qtbase, and are not on any default plugin search path. Without
    # this, QML Image fails to decode .webp wallpapers and the card renders
    # blank. writeShellApplication has no makeWrapper hook to set this via
    # --prefix (a makeWrapper --prefix would be the alternative), so it is
    # exported here directly instead — the smaller change for a single plain
    # env var, versus restructuring this derivation just to gain makeWrapper.
    export QT_PLUGIN_PATH="${qt6.qtimageformats}/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"

    # Wallpapers are per monitor: pin this session to the one focused when the
    # picker was opened, before the overlay exists and can affect focus.
    # Empty (no hyprctl) is fine — apply.sh then resolves it per call.
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
