# ── wallpaper-picker ────────────────────────────────────────────────────────
# Wrapper for the Quickshell wallpaper selector whose QML lives at
# home/quickshell/wallpaper-picker/ and is symlinked live into
# ~/.config/quickshell/wallpaper-picker (see home/modules/wallpaper-picker.nix).
#
# The QML is deliberately NOT copied into the store: keeping it out-of-store
# means it can be edited and re-run without a rebuild, matching how rofi, qt6ct
# and hypr configs are handled in this repo.
#
# What the store DOES own is the dependency closure. Launched from a Hyprland
# keybind the process inherits Hyprland's PATH, which does not reliably carry
# quickshell/awww/mpvpaper/jq — hence the explicit wrapping.
#
# hyprctl, which apply.sh also calls (to pick a monitor for apply_video), is
# deliberately NOT in runtimeInputs: writeShellApplication's generated wrapper
# PREFIXES this closure onto PATH rather than replacing it, so hyprctl still
# resolves from the session PATH where Hyprland already put it. If it is ever
# unavailable there, apply_video falls back to mon="*".
{
  lib,
  writeShellApplication,
  quickshell,
  awww,
  mpvpaper,
  ffmpegthumbnailer,
  jq,
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
    # --prefix (see qs-wallpaper-picker.nix for that approach), so it is
    # exported here directly instead — the smaller change for a single plain
    # env var, versus restructuring this derivation just to gain makeWrapper.
    export QT_PLUGIN_PATH="${qt6.qtimageformats}/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"

    exec quickshell -p "$CONFIG_DIR"
  '';

  meta = {
    description = "Skewed-carousel Quickshell wallpaper selector";
    mainProgram = "wallpaper-picker";
    platforms = lib.platforms.linux;
  };
}
