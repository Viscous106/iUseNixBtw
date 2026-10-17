# Opera repacked from the official .deb (nixpkgs dropped `opera`); modelled on
# nixpkgs' google-chrome. Fetch from get.geo.opera.com, not deb.opera.com: the
# apt pool only keeps the current release, and its .deb uses .xz, not .zst.
# Update: bump version, hash = lib.fakeHash, build, paste the real hash.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  patchelf,
  bintools,
  zstd,

  # ── Directly linked libraries (readelf -d over the .deb) ─────────────────
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  curl,
  dbus,
  expat,
  gcc-unwrapped,
  glib,
  libgbm,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  systemd,

  # ── Loaded at runtime (dlopen), not in DT_NEEDED ─────────────────────────
  # Same set google-chrome ships; Chromium reaches for these lazily.
  fontconfig,
  freetype,
  gdk-pixbuf,
  gtk3,
  libdrm,
  libglvnd,
  libxcursor,
  libxi,
  libxrender,
  libxshmfence,
  libxtst,
  pciutils,
  pipewire,
  vulkan-loader,
  wayland,
  xdg-utils,

  # ── Qt theme-integration shims (libqt5_shim.so / libqt6_shim.so) ─────────
  qt5,
  qt6,

  # ── Icon/schema lookup paths + GPU driver link ───────────────────────────
  adwaita-icon-theme,
  gsettings-desktop-schemas,
  addDriverRunpath,

  libpulseaudio,
  pulseSupport ? true,
  libva,
  libvaSupport ? true,

  # Flags always appended to the wrapper, e.g. "--disable-gpu"
  commandLineArgs ? "",
}:

let
  deps = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curl
    dbus
    expat
    fontconfig
    freetype
    gcc-unwrapped.lib
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxshmfence
    libxtst
    nspr
    nss
    pango
    pciutils
    pipewire
    qt5.qtbase
    qt6.qtbase
    systemd
    vulkan-loader
    wayland
  ]
  ++ lib.optional pulseSupport libpulseaudio
  ++ lib.optional libvaSupport libva;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opera";
  version = "135.0.5973.76";

  src = fetchurl {
    url = "https://get.geo.opera.com/pub/opera/desktop/${finalAttrs.version}/linux/opera-stable_${finalAttrs.version}_amd64.deb";
    hash = "sha256-bqqiFFVB+RGbGT3QrwTV8i+3+OiATKrLMPb2Hic1+wM=";
  };

  # Matches google-chrome: shebang patching misbehaves under strictDeps here.
  strictDeps = false;

  nativeBuildInputs = [
    makeWrapper
    patchelf
    zstd
  ];

  buildInputs = [
    # populates $XDG_ICON_DIRS
    adwaita-icon-theme
    glib
    gtk3
    # populates $GSETTINGS_SCHEMAS_PATH
    gsettings-desktop-schemas
  ];

  unpackPhase = ''
    runHook preUnpack
    ${lib.getExe' bintools "ar"} x $src
    tar xf data.tar.zst
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    # The .deb nests everything under a multiarch triplet dir; flatten it to
    # $out/lib/opera the way the AUR PKGBUILD flattens it to /usr/lib/opera.
    mkdir -p $out/bin $out/lib $out/share
    cp -a usr/lib/x86_64-linux-gnu/opera-stable $out/lib/opera
    cp -a usr/share/applications $out/share/
    cp -a usr/share/icons        $out/share/
    cp -a usr/share/pixmaps      $out/share/

    # Prefer nixpkgs' vulkan-loader over the bundled copy (as google-chrome does).
    rm -v $out/lib/opera/libvulkan.so.1
    ln -s ${lib.getLib vulkan-loader}/lib/libvulkan.so.1 $out/lib/opera/libvulkan.so.1

    # `opera` has libffmpeg.so in its DT_NEEDED and that .so lives alongside the
    # binary, so opera's own libdir MUST be on the rpath — not just the nixpkgs
    # deps. This is the one place this derivation differs from google-chrome's.
    rpath="$out/lib/opera:${lib.makeLibraryPath deps}:${lib.makeSearchPathOutput "lib" "lib64" deps}"

    for elf in \
      $out/lib/opera/opera \
      $out/lib/opera/opera_sandbox \
      $out/lib/opera/opera_autoupdate \
      $out/lib/opera/opera_crashreporter \
      $out/lib/opera/chrome_crashpad_handler \
      $out/lib/opera/*.so \
      $out/lib/opera/*.so.[0-9] ; do
      [ -f "$elf" ] || continue
      # libvulkan.so.1 is now a symlink into the (read-only) store copy of
      # vulkan-loader -- patchelf would follow it and die with
      # "patchelf: open: Permission denied". Nothing to patch there anyway.
      [ -L "$elf" ] && continue
      patchelf --set-rpath "$rpath" "$elf" || true
      # Only the executables carry a PT_INTERP; setting it on a .so errors out.
      if patchelf --print-interpreter "$elf" >/dev/null 2>&1; then
        patchelf --set-interpreter ${bintools.dynamicLinker} "$elf"
      fi
    done

    makeWrapper $out/lib/opera/opera $out/bin/opera \
      --prefix LD_LIBRARY_PATH : "$rpath" \
      --prefix PATH            : "${lib.makeBinPath [ xdg-utils ]}" \
      --prefix XDG_DATA_DIRS   : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH:${addDriverRunpath.driverLink}/share" \
      --prefix QT_PLUGIN_PATH  : "${qt6.qtbase}/lib/qt-6/plugins" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --add-flags ${lib.escapeShellArg commandLineArgs}

    # The .desktop ships bare `Exec=opera`, which only resolves if $out/bin is
    # already on the launcher's PATH. Point it at the wrapper instead.
    # Order matters: 'TryExec=opera' CONTAINS the substring 'Exec=opera', so
    # substituting Exec first also rewrites the TryExec line, and the TryExec
    # --replace-fail then matches nothing and fails the build. Do TryExec first.
    substituteInPlace $out/share/applications/opera.desktop \
      --replace-fail 'TryExec=opera' "TryExec=$out/bin/opera" \
      --replace-fail 'Exec=opera'    "Exec=$out/bin/opera"

    runHook postInstall
  '';

  meta = {
    description = "Fast, secure, easy-to-use Chromium-based web browser";
    homepage = "https://www.opera.com/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "opera";
  };
})
