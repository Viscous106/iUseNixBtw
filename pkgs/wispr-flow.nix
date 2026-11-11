# Wispr Flow repacked from the unofficial wispr-flow-linux .deb (their flake needs a hand-supplied
# installer). Update: bump version/port, lib.fakeHash, build, paste hash.
{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gcc-unwrapped,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxshmfence,
  libxtst,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  vulkan-loader,
  wayland,
  wl-clipboard,
  xclip,
  xsel,
}:

let
  # Linked at build time (DT_NEEDED).
  buildLibs = [
    alsa-lib at-spi2-core atk cairo cups dbus expat gcc-unwrapped.lib glib gtk3 libgbm
    libx11 libxcb libxcomposite libxdamage libxext libxfixes libxkbcommon libxrandr nspr nss
    pango systemd
  ];
  # Chromium dlopens these at runtime.
  dlopenLibs = [
    fontconfig freetype libdrm libglvnd libxcursor libxi libxrender libxshmfence libxtst
    pipewire vulkan-loader wayland
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "wispr-flow";
  version = "1.6.1337";
  port = "1.0.5";

  src = fetchurl {
    url = "https://github.com/wispr-flow-linux/wispr-flow-linux/releases/download/v${finalAttrs.port}%2Bwispr${finalAttrs.version}/wispr-flow_${finalAttrs.version}-${finalAttrs.port}_amd64.deb";
    hash = "sha256-PwOf8sqOZKxFY3CWhUBZz+vhIuRV6fYoP5HNjYjcH1Y=";
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook makeWrapper ];
  buildInputs = buildLibs;

  # The bundled libffmpeg.so/libEGL.so sit next to the binary and are not nixpkgs deps.
  autoPatchelfIgnoreMissingDeps = [ "libffmpeg.so" ];
  appendRunpaths = [ "${placeholder "out"}/lib/wispr-flow" (lib.makeLibraryPath dlopenLibs) ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/share
    cp -a usr/lib/wispr-flow $out/lib/wispr-flow
    cp -a usr/share/applications usr/share/icons $out/share/

    # The launcher hardcodes /usr/lib/wispr-flow.
    install -Dm755 usr/bin/wispr-flow $out/bin/wispr-flow
    substituteInPlace $out/bin/wispr-flow \
      --replace-fail 'app_dir="/usr/lib/wispr-flow"' 'app_dir="'$out'/lib/wispr-flow"'

    # Setuid is impossible in the store; Chromium falls back to the userns sandbox.
    rm $out/lib/wispr-flow/chrome-sandbox

    # The session's LD_LIBRARY_PATH (audio shim) outranks RUNPATH and pulls in a libasound built against a newer glibc.
    wrapProgram $out/bin/wispr-flow \
      --unset LD_LIBRARY_PATH \
      --prefix PATH : ${lib.makeBinPath [ wl-clipboard xclip xsel ]}

    runHook postInstall
  '';

  meta = {
    description = "Wispr Flow voice dictation (unofficial Linux port)";
    homepage = "https://github.com/wispr-flow-linux/wispr-flow-linux";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "wispr-flow";
  };
})
