# ── qs-wallpaper-picker — Quickshell wallpaper selector ─────────────────────
#
# WHY THIS FILE EXISTS
# Upstream (github.com/magetsu002/qs-wallpaper-picker) ships as a git clone you
# run in place: `cp config/Settings.qml.example config/Settings.qml` and then
# `./scripts/open_picker.sh`. Two things make that unworkable as-is on NixOS:
#
#   1. WallpaperPicker.qml instantiates `Settings {}`, so config/Settings.qml
#      must exist as a real file next to the QML. The repo only ships the
#      .example, and the store is read-only, so the copy has to happen at build
#      time rather than on first run.
#   2. open_picker.sh calls quickshell, awww, magick, ffmpeg, mpvpaper, flock
#      and python3 by bare name. Launched from a Hyprland keybind it inherits
#      Hyprland's PATH, which does not reliably carry all of those.
#
#   3. WallpaperPicker.qml imports QtMultimedia (it previews video wallpapers).
#      The nixpkgs quickshell has no `withModules` passthru the way outfoxxed's
#      flake build does, so the module is supplied through QML2_IMPORT_PATH.
#      Without it the shell dies at load: `module "QtMultimedia" is not
#      installed`.
#
# All three are solved by copying the tree into the store, generating
# Settings.qml, and wrapping the launcher with an explicit PATH and QML path.
#
# The scripts themselves need no patching: every shebang is the portable
# `#!/usr/bin/env bash` or `#!/usr/bin/env python3` form, so bash and python3
# being on the wrapped PATH is sufficient.
#
# WHY THIS AND NOT CAELESTIA'S OWN PICKER
# Caelestia has no one-press wallpaper picker. Its CLI has no picker flag
# (-f FILE / -r random only), there is no IPC to open the launcher in wallpaper
# mode, and nexus is a full settings window rather than a menu. It is also
# images-only — services/Wallpapers.qml filters on FileSystemModel.Images and
# modules/background/Wallpaper.qml renders through CachingImage, with no
# mpv/video/AnimatedImage path anywhere. This picker handles video too, via the
# same mpvpaper this config already uses for live wallpapers.
#
# NOT PACKAGED IN NIXPKGS — this is third-party, unaudited upstream code,
# pinned by revision below so it cannot move under us.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  bash,
  python3,
  quickshell,
  awww,
  imagemagick,
  ffmpeg,
  mpvpaper,
  coreutils,
  util-linux, # flock — open_picker.sh uses it to enforce a single instance
  jq,
  qt6,
  # Optional. Upstream's Settings.qml.example defaults enableDynamicColors to
  # false and this config leaves it there: caelestia already owns the colour
  # scheme, and having matugen regenerate it too would give two things fighting
  # over the same palette.
  matugen,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "qs-wallpaper-picker";
  version = "0-unstable-2026-08-22";

  src = fetchFromGitHub {
    owner = "magetsu002";
    repo = "qs-wallpaper-picker";
    rev = "c81fe1d4c3485b7dc39e0cd0aa82ccc6228ed9f6";
    hash = "sha256-RwzkYOSS3+aoTh7TSqnZlMVB3JMOCdera8GrbPyO6RM=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/qs-wallpaper-picker
    cp -r . $out/share/qs-wallpaper-picker/

    # See note 1 above — generate the config the QML actually imports.
    cp config/Settings.qml.example $out/share/qs-wallpaper-picker/config/Settings.qml

    chmod +x $out/share/qs-wallpaper-picker/scripts/*.sh \
             $out/share/qs-wallpaper-picker/scripts/*.py

    mkdir -p $out/bin
    makeWrapper $out/share/qs-wallpaper-picker/scripts/open_picker.sh \
      $out/bin/qs-wallpaper-picker \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          python3
          quickshell
          awww
          imagemagick
          ffmpeg
          mpvpaper
          coreutils
          util-linux
          jq
          matugen
        ]
      }  \
      --prefix QML2_IMPORT_PATH : "${qt6.qtmultimedia}/lib/qt-6/qml"

    # Also expose upstream's restore script. It reapplies the last wallpaper at
    # login and handles BOTH kinds — awww img for images, mpvpaper for video —
    # which is exactly the job this config's own wallpaper-restore.sh was doing
    # by hand, so startup_apps.lua now calls this instead.
    makeWrapper $out/share/qs-wallpaper-picker/scripts/restore_wallpaper.sh \
      $out/bin/qs-wallpaper-restore \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          python3
          awww
          imagemagick
          ffmpeg
          mpvpaper
          coreutils
          util-linux
          jq
          matugen
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Keyboard-first Quickshell wallpaper picker for Hyprland, with image and video support";
    homepage = "https://github.com/magetsu002/qs-wallpaper-picker";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "qs-wallpaper-picker";
  };
})
