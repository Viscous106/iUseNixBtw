{ config, pkgs, lib, ... }:

{
  # ── Steam ────────────────────────────────────────────────────────────────
  # programs.steam.enable is the standard NixOS way to install Steam: it
  # wires up the 32-bit graphics/audio libraries the Steam runtime needs,
  # opens the right firewall ports for Remote Play/Local Network Game
  # Transfers when asked, and adds udev rules for controllers — all the
  # "lib32-*" plumbing Arch's multilib repo does by hand as separate
  # packages (see note near the bottom of this file).
  programs.steam.enable = true;

  # ── ASUS ROG hardware tools (asusctl / rog-control-center / supergfxctl) ──
  # These three Arch packages only do anything on ASUS ROG laptops. On any
  # other machine asusd/supergfxd just fail to find their hardware and sit
  # idle — the same "detect, no-op if absent" pattern hardware-universal.nix
  # already uses for thermald (Intel-only, `lib.mkDefault false` there
  # because it *changes power behavior* if wrongly enabled; asusd/supergfxd
  # don't have that failure mode, they're pure hardware-detection daemons,
  # so enabling them outright here is safe on non-ASUS hardware too).
  #
  # programs.rog-control-center.enable pulls in `asusctl` (which provides
  # both the `asusctl` CLI and the `rog-control-center` GUI binary) and
  # turns on services.asusd itself — covers asusctl + rog-control-center.
  programs.rog-control-center.enable = true;
  # supergfxctl (dGPU mux/power switching) is a separate daemon/package.
  services.supergfxd.enable = true;

  # ── QMK — flash/debug QMK-based keyboards without root ────────────────────
  # Just installs udev rules granting the plugdev group USB access to QMK
  # devices; a harmless no-op on machines with no QMK keyboard plugged in.
  hardware.keyboard.qmk.enable = true;

  # ── OpenRGB — RGB peripheral control ──────────────────────────────────────
  # Installed as a plain package (NOT via services.hardware.openrgb, which
  # would run `openrgb --server` as an always-on systemd unit). Arch's
  # openrgb package doesn't auto-start a service either, so this matches
  # that: available on demand from the app menu/CLI. udev rules are still
  # registered so it works without sudo, and i2c-dev is loaded for
  # motherboard RGB header support (a no-op without i2c hardware present).
  services.udev.packages   = [ pkgs.openrgb ];
  boot.kernelModules        = [ "i2c-dev" ];

  environment.systemPackages = with pkgs; [
    # ── Wine / gaming launchers ──────────────────────────────────────────
    # wine-staging (the literal attribute matching the Arch package name)
    # is a 32-bit-only build in nixpkgs (`winePackagesFor "wine32"`), which
    # can't run 64-bit-only Windows games. Arch's multilib wine-staging
    # supports both 32- and 64-bit PE binaries, so the correct functional
    # equivalent is wineWow64Packages.stagingFull (staging patchset, full
    # feature set, WoW64 32+64-bit support).
    wineWow64Packages.stagingFull
    winetricks
    lutris
    heroic                      # matches heroic-games-launcher-bin
    # an-anime-game-launcher-bin: AUR-only prebuilt binary (genshin-impact
    # launcher fork). No nixpkgs equivalent exists under any name I could
    # find (checked pkgs/by-name, pkgs/games, pkgs/top-level/all-packages.nix)
    # — SKIPPED, unavailable in nixpkgs.

    # ── GPU tooling ───────────────────────────────────────────────────────
    nvtopPackages.full          # GPU usage monitor; auto-detects Intel/AMD/NVIDIA
    # nvidia-settings: SKIPPED. In nixpkgs it isn't a standalone userspace
    # package — it only exists as `<nvidiaDriverPackage>.settings`
    # (pkgs/os-specific/linux/nvidia-x11/settings.nix), i.e. it's built as
    # an output of the actual proprietary NVIDIA driver derivation
    # (linuxPackages.nvidia_x11 or equivalent). Pulling that in — even just
    # to get the GUI tool, even without setting it as the active driver —
    # means evaluating/building the unfree NVIDIA kernel-module package on
    # every machine this portable drive boots on, which conflicts with the
    # "boots on any GPU vendor, driver-agnostic" design goal more than a
    # plain package normally would. Deliberately left out; if this drive
    # ends up living on an NVIDIA machine long-term, add
    # `pkgs.linuxPackages.nvidia_x11.settings` (or the appropriate
    # config.boot.kernelPackages.nvidiaPackages.*.settings) at that point.

    # vulkan-intel / vulkan-nouveau / vulkan-radeon: none of these exist as
    # separate nixpkgs packages — Mesa ships the ANV (Intel), RADV (AMD),
    # and NVK (nouveau) Vulkan drivers itself, already pulled in by
    # hardware.graphics.enable / enable32Bit (already set in
    # hardware-universal.nix). Nothing to add.

    # lib32-giflib, lib32-gnutls, lib32-gst-plugins-base-libs, lib32-gtk3,
    # lib32-libjpeg-turbo, lib32-libpulse, lib32-libxcomposite, lib32-libxslt,
    # lib32-mpg123, lib32-ocl-icd, lib32-openal, lib32-v4l-utils,
    # lib32-vulkan-icd-loader:
    # nixpkgs has no "lib32-X" compat-shim packages — that's an Arch
    # multilib-repo concept for satisfying dynamically-linked system
    # binaries. Nix's wine derivation (pkgs/applications/emulators/wine)
    # declares these as build inputs directly per support flag
    # (pulseaudioSupport, gstreamerSupport, cupsSupport, openclSupport,
    # v4lSupport, etc. — see pkgs/top-level/wine-packages.nix) and gets a
    # self-contained closure per architecture; Steam's 32-bit needs are
    # covered by hardware.graphics.enable32Bit (already on). Nothing to add.

    # ── Peripheral control ────────────────────────────────────────────────
    openrgb
    openrgb-plugin-effects       # matches openrgb-plugin-effects-git (AUR
                                 # "-git" suffix just meant "built from git
                                 # HEAD"; nixpkgs packages a stable release
                                 # of the same plugin under this plain name)
    qmk                          # QMK CLI (compiling/flashing firmware)
  ];
}
