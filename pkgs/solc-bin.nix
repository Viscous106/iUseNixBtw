{ lib, runCommandLocal, fetchurl }:

# Pinned upstream solc (nixpkgs ships one; ~/.svm is outside the lock). Static binaries, so
# runCommandLocal installs them as-is with no patchelf/strip. Used by home/dev/web3.nix.

{ version, sha256 }:

let
  src = fetchurl {
    url =
      "https://github.com/ethereum/solidity/releases/download/v${version}/solc-static-linux";
    inherit sha256;
  };
in
runCommandLocal "solc-${version}"
{
  meta = with lib; {
    description = "Solidity compiler ${version} (official static Linux build)";
    homepage = "https://github.com/ethereum/solidity";
    license = licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    # solc-<version>, never bare solc, so versions coexist with pkgs.solc.
    mainProgram = "solc-${version}";
  };
}
  ''
    mkdir -p "$out/bin"
    cp ${src} "$out/bin/solc-${version}"
    chmod +x "$out/bin/solc-${version}"
  ''
