{ pkgs, ... }:

{
  # ── Editors, office suite, journal, and misc CLI utilities ─────────────────
  # Migrated from the Arch install's explicitly-installed package list.
  # Every attribute below was verified to exist by grepping the fetched
  # nixpkgs source tree (pkgs/by-name + pkgs/top-level/all-packages.nix)
  # before being added — nothing here is guessed.
  home.packages = with pkgs; [
    # Editors
    code-cursor     # AUR `cursor-bin`; nixpkgs attribute is `code-cursor` (its
                    # pname is "cursor" but the by-name attr is code-cursor).
                    # NOTE: unfree (already allowed globally in configuration.nix).
    # NOTE: `visual-studio-code-insiders-bin` has NO nixpkgs equivalent in this
    # tree — only `vscode`, `vscode-fhs`, `vscodium`, and `vscodium-fhs` exist
    # (pkgs/top-level/all-packages.nix); no Insiders build is packaged.
    mousepad        # GTK text editor
    nano

    # Office / spelling
    libreoffice-fresh   # matches the AUR package name exactly (the "fresh"
                        # release branch has its own attribute, verified at
                        # pkgs/applications/office/libreoffice, distinct from
                        # `libreoffice` == libreoffice-still)
    hunspellDicts.en_US # AUR `hunspell-en_us`; nixpkgs ships dictionaries under
                        # the hunspellDicts attribute set, not as flat packages
                        # (pkgs/by-name/hu/hunspell/dictionaries.nix)

    # Journal
    tui-journal     # mainProgram = "tjournal", which matches the `scrible`
                    # alias in home/modules/zsh.nix (scrible = "tjournal")

    # Networking / testing utilities
    speedtest-cli   # sivel/speedtest-cli; exposed at top level via
                    # `toPythonApplication` (all-packages.nix) — NOT the
                    # `speedtest` attribute, which is an unrelated GTK4 app
    prettyping
    postman         # AUR `postman-bin` -> nixpkgs `postman`

    # GIS
    qgis

    # AI agent / coding CLIs
    goose-cli       # Block's AI agent (github.com/block/goose). NOTE: the
                    # bare `goose` attribute in nixpkgs is an UNRELATED Go
                    # database-migration tool (pressly/goose) — using it here
                    # would be wrong, so goose-cli is the correct pick.
    opencode        # AI coding agent CLI, verified present at
                    # pkgs/by-name/op/opencode
    github-copilot-cli  # NOTE: contrary to expectation this is NOT just a
                        # `gh` extension — nixpkgs packages it standalone
                        # (fetches github/copilot-cli's own release tarball,
                        # installs a `copilot` binary). Unfree license.
                        # Do NOT confuse with the `copilot-cli` attribute,
                        # which is AWS's unrelated ECS deployment tool.
  ];
}
