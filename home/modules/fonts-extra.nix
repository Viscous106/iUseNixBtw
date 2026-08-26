{ pkgs, ... }:

{
  # ── Fonts + the Qt/X11 "leftover" bucket from the Arch package audit ──────
  # Migrated from the Arch install's explicitly-installed package list.
  # Every attribute below was verified to exist by grepping the pinned
  # nixpkgs source tree (pkgs/by-name + pkgs/data/fonts + pkgs/top-level/
  # all-packages.nix) before being added — nothing here is guessed.
  #
  # Already covered by modules/desktop.nix `fonts.packages` — skipped here to
  # avoid duplicating:
  #   - ttf-jetbrains-mono-nerd  -> nerd-fonts.jetbrains-mono (already declared)
  #   - ttf-firacode-nerd        -> nerd-fonts.fira-code      (already declared)
  #   - noto-fonts-emoji         -> noto-fonts-color-emoji    (already declared;
  #     Arch splits emoji out of noto-fonts, nixpkgs bundles it as one pkg)
  #
  # Verified to NOT exist in the pinned nixpkgs and skipped:
  #   - ttf-droid  — the Droid font family was retired upstream years ago
  #     (superseded by Roboto/Noto); no `droid*` font package anywhere in
  #     pkgs/by-name or pkgs/data/fonts. Not substituted with anything here
  #     since noto-fonts (its spiritual successor) is already declared in
  #     desktop.nix.
  home.packages = with pkgs; [
    # ── Adobe Source Code Pro (adobe-source-code-pro-fonts) ────────────────
    source-code-pro

    # ── Victor Mono (ttf-victor-mono) ──────────────────────────────────────
    victor-mono

    # ── Vanilla (unpatched) Fira Code / JetBrains Mono ─────────────────────
    # Upstream Nerd Fonts release tarballs (what nerd-fonts.fira-code /
    # nerd-fonts.jetbrains-mono in desktop.nix build from) ship ONLY
    # icon-patched, renamed families ("FiraCode Nerd Font", "JetBrainsMono
    # Nerd Font [Mono|Propo]") — they do not include the plain "Fira Code" /
    # "JetBrains Mono" family names Arch's ttf-fira-code / ttf-jetbrains-mono
    # install. Adding the vanilla packages too so anything that hardcodes
    # the unpatched family name still resolves.
    fira-code
    jetbrains-mono

    # ── Meslo Nerd Font + Powerlevel10k's exact recommended build ─────────
    # ttf-meslo-nerd -> nerd-fonts.meslo-lg (new namespaced nerd-fonts set)
    # ttf-meslo-nerd-font-powerlevel10k -> meslo-lgs-nf, a standalone
    # nixpkgs package built straight from romkatv/powerlevel10k-media,
    # i.e. the exact "MesloLGS NF" hinting p10k's docs tell you to install.
    nerd-fonts.meslo-lg
    meslo-lgs-nf

    # ── Standalone Nerd Font "Symbols Only" glyph set ──────────────────────
    # Covers all three Arch splits in one package: ttf-nerd-fonts-symbols,
    # ttf-nerd-fonts-symbols-common, ttf-nerd-fonts-symbols-mono. Verified
    # via pkgs/data/fonts/nerd-fonts/manifests/fonts.json (caskName
    # "symbols-only" -> attribute nerd-fonts.symbols-only).
    nerd-fonts.symbols-only

    # ── Font Awesome OTF icon font (otf-font-awesome) ──────────────────────
    # `font-awesome` defaults to the v7 OTF-only build, matching Arch's
    # otf-font-awesome package exactly.
    font-awesome

    # ── Microsoft core fonts (ttf-ms-fonts) ────────────────────────────────
    # nixpkgs attribute is `corefonts` (Arial/Times New Roman/Courier New/
    # etc. repackaged from Microsoft's EULA'd installers via cabextract).
    # meta.license = lib.licenses.unfreeRedistributable, so this will fail
    # to evaluate/build unless unfree packages are allowed somewhere in the
    # config (nixpkgs.config.allowUnfree = true, or an allowUnfreePredicate
    # matching "corefonts"). Left as a plain package reference here since
    # this file intentionally only declares packages — whoever wires the
    # unfree toggle should be aware this package needs it.
    corefonts

    # ── Not fonts, but bundled into this same "leftover" Arch package group ─

    # Qt5 charting library (qt5-charts)
    qt5.qtcharts

    # Qt Wayland platform-plugin (QPA) support for Qt5/Qt6 apps
    # (qt5-wayland / qt6-wayland). Hyprland itself is wlroots-based and does
    # NOT need these to run. qt6.qtwayland is already pulled into the store
    # transitively as a *build* input of xdg-desktop-portal-hyprland and of
    # qt6Packages.qt6ct (see desktop.nix) — but neither of those exposes its
    # plugin directory system-wide via QT_PLUGIN_PATH; that wiring only
    # happens through the NixOS/home-manager `qt.enable` module, which is
    # NOT set anywhere in this config (grepped the whole repo — no `qt.enable`
    # or direct qtwayland reference exists yet). So without adding these
    # explicitly, any other Qt5/Qt6 app you run would silently fall back to
    # XWayland instead of the native Wayland platform plugin. Declaring them
    # here guarantees the plugin is actually present in the profile.
    qt5.qtwayland
    qt6.qtwayland

    # X11-only display-layout GUI (arandr). nwg-displays (already installed
    # per earlier work this session) is the native Wayland/Hyprland
    # equivalent, so this is redundant for the Hyprland session itself —
    # kept anyway since it's cheap and still useful for configuring XWayland
    # apps or any X11 fallback.
    arandr
  ];
}
