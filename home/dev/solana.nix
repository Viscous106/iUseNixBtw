{ ... }:

# Solana CLI from the Anza installer, not nixpkgs: pkgs.solana-cli lacks cargo-build-sbf, which `anchor build` needs.
# nix-ld runs these prebuilt binaries; anchor itself comes from avm into ~/.cargo/bin.
{
  home.sessionPath = [ "$HOME/.local/share/solana/install/active_release/bin" ];
}
