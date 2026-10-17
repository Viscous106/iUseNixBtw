{ pkgs, ... }:

{
  # ── Editors, office suite, journal, and misc CLI utilities ─────────────────
  # Migrated from the Arch install's explicitly-installed package list.
  # Every attribute below was verified to exist by grepping the fetched
  # nixpkgs source tree (pkgs/by-name + pkgs/top-level/all-packages.nix)
  # before being added — nothing here is guessed.
  home.packages = with pkgs; [
    obsidian
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
    libreoffice-stable  # upstream renamed the branches; `libreoffice-fresh` is
                        # now an alias that warns. Verified identical: both
                        # -fresh and -stable resolve to the same derivation
                        # (libreoffice-26.2.5.2-wrapped), so this is a no-op.
    hunspellDicts.en_US # AUR `hunspell-en_us`; nixpkgs ships dictionaries under
                        # the hunspellDicts attribute set, not as flat packages
                        # (pkgs/by-name/hu/hunspell/dictionaries.nix)

    # Journal
    tui-journal     # mainProgram = "tjournal", which matches the `scrible`
                    # alias in home/shell/zsh.nix (scrible = "tjournal")

    # Networking / testing utilities
    speedtest-cli   # sivel/speedtest-cli; exposed at top level via
                    # `toPythonApplication` (all-packages.nix) — NOT the
                    # `speedtest` attribute, which is an unrelated GTK4 app
    prettyping
    # postman       # disabled: upstream mirror (dl.pstmn.io) is unreliable; re-enable when fixed

    # GIS
    qgis
  ];
}
