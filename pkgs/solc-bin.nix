{ lib, runCommandLocal, fetchurl }:

# ── Pinned Solidity compiler, straight from the official release ──────────────
# Solidity is unusually version-sensitive: a contract written against 0.6.x will
# not compile under 0.8.x, so following older material means having older
# compilers available. nixpkgs carries exactly one solc (0.8.33 at the time of
# writing, `pkgs/by-name/so/solc`), which is not enough on its own.
#
# Foundry's own answer is `svm`, which downloads compilers into ~/.svm at first
# use. That is rejected here for the same reason `foundryup` was rejected in
# home/modules/dev-toolchains.nix: it is mutable state outside the flake lock,
# and it fails outright on a read-only filesystem.
#
# The upstream Linux release binaries are *statically linked*, so unlike most
# downloaded binaries on NixOS they need no autoPatchelf and no interpreter
# rewrite — verified by running the fetched 0.6.12 binary directly. That makes a
# plain fetchurl pinned by hash sufficient, and keeps every compiler version
# reproducible and locked.
#
# `runCommandLocal` is deliberate: setting `buildCommand` bypasses stdenv's
# generic build, so no fixup or strip phase runs and the static binary is
# installed byte-for-byte as upstream shipped it.
#
# Usage (see home/modules/web3.nix):
#   pkgs.solc-bin { version = "0.6.12"; sha256 = "f6cb519b..."; }
#
# To add a version, get its hash with:
#   nix-prefetch-url https://github.com/ethereum/solidity/releases/download/v<VER>/solc-static-linux

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
    # Installed as solc-<version>, never bare `solc`, so that several versions
    # can sit in one profile without colliding with each other or with
    # pkgs.solc. mainProgram matches that name.
    mainProgram = "solc-${version}";
  };
}
  ''
    mkdir -p "$out/bin"
    cp ${src} "$out/bin/solc-${version}"
    chmod +x "$out/bin/solc-${version}"
  ''
