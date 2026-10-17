{ pkgs, ... }:

{
  # ── Fonts + Qt extras ───────────────────────────────────────────────────────
  # Nerd-patched JetBrains/Fira and Noto live in system/desktop.nix fonts.packages.
  home.packages = with pkgs; [
    source-code-pro
    victor-mono

    # Unpatched families, for anything that hardcodes "Fira Code"/"JetBrains Mono".
    fira-code
    jetbrains-mono

    nerd-fonts.meslo-lg
    meslo-lgs-nf # exact "MesloLGS NF" build Powerlevel10k expects
    nerd-fonts.symbols-only
    font-awesome
    corefonts # Arial, Times New Roman, Courier New, …

    qt5.qtcharts

    # Native Wayland plugin for Qt apps; qt.enable is not set, so without these
    # they fall back to XWayland.
    qt5.qtwayland
    qt6.qtwayland
  ];
}
