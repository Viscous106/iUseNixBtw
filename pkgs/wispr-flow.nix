# Wispr Flow from the unofficial wispr-flow-linux AppImage; its flake build skips the Linux
# native-module rebuild. Update: bump version/port, lib.fakeHash, build, paste hash.
{
  lib,
  appimageTools,
  fetchurl,
  wl-clipboard,
}:

let
  pname   = "wispr-flow";
  version = "1.6.957";
  port    = "1.0.4";

  src = fetchurl {
    url  = "https://github.com/wispr-flow-linux/wispr-flow-linux/releases/download/v${port}%2Bwispr${version}/wispr-flow-${version}-${port}-x86_64.AppImage";
    hash = "sha256-2jeeMDWVnkadE5lyjwb1ThKplYoxp5P/GgZ39OEtiMU=";
  };

  contents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = _: [ wl-clipboard ];

  extraInstallCommands = ''
    install -Dm444 ${contents}/ai.wisprflow.WisprFlow.desktop $out/share/applications/wispr-flow.desktop
    substituteInPlace $out/share/applications/wispr-flow.desktop --replace-fail 'Exec=AppRun' 'Exec=wispr-flow'
    install -Dm444 ${contents}/ai.wisprflow.WisprFlow.png \
      $out/share/icons/hicolor/256x256/apps/ai.wisprflow.WisprFlow.png
  '';

  meta = {
    description = "Wispr Flow voice dictation (unofficial Linux port)";
    homepage = "https://github.com/wispr-flow-linux/wispr-flow-linux";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "wispr-flow";
  };
}
