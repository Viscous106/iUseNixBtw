{
  description = "Foundry project";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # ── Compiler for this project ───────────────────────────────────────
      # "nixpkgs" (its solc) or a knownSolc key, e.g. "0.6.12"; the shell passes it via FOUNDRY_SOLC.
      solcVersion = "nixpkgs";

      # version -> sha256 of solc-static-linux (static, runs unpatched). Add with:
      #   nix-prefetch-url https://github.com/ethereum/solidity/releases/download/v<VER>/solc-static-linux
      knownSolc = {
        "0.6.12" = "f6cb519b01dabc61cab4c184a3db11aa591d18151e362fcae850e42cffdfb09a";
      };

      # Duplicated from pkgs/solc-bin.nix so this project builds with plain Nix on any machine.
      solcBin = version: sha256:
        let
          src = pkgs.fetchurl {
            url = "https://github.com/ethereum/solidity/releases/download/v${version}/solc-static-linux";
            inherit sha256;
          };
        in
        pkgs.runCommandLocal "solc-${version}" { } ''
          mkdir -p "$out/bin"
          cp ${src} "$out/bin/solc-${version}"
          chmod +x "$out/bin/solc-${version}"
        '';

      solc =
        if solcVersion == "nixpkgs" then {
          pkg = pkgs.solc;
          exe = "solc";
        } else {
          pkg = solcBin solcVersion knownSolc.${solcVersion};
          exe = "solc-${solcVersion}";
        };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.foundry # forge, cast, anvil, chisel
          pkgs.just
          pkgs.jq # the justfile's deploy recipe parses forge's --json output
          solc.pkg
        ];

        # The whole per-project pinning mechanism, in one line. forge reads this
        # and skips its own ~/.svm downloader entirely.
        FOUNDRY_SOLC = "${solc.pkg}/bin/${solc.exe}";

        shellHook = ''
          echo "foundry $(forge --version | head -1 | cut -d' ' -f3) | solc $("$FOUNDRY_SOLC" --version | tail -1 | cut -d' ' -f2 | cut -d'+' -f1)"
        '';
      };
    };
}
