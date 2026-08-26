{ config, pkgs, inputs, ... }:

# ── Programming-language toolchains & dev CLI tools ────────────────────────
# Ports the language/toolchain-related Arch packages over 1:1 where nixpkgs
# has a matching attribute. Every package name below was verified to exist
# in the fetched nixpkgs source tree before being added here — see the
# migration report for what was checked and what was intentionally skipped.
{
  home.packages = with pkgs; [
    # ── Go ──────────────────────────────────────────────────────────────
    go
    golangci-lint

    # ── Rust ────────────────────────────────────────────────────────────
    # rustup itself is a slightly odd fit for Nix (nixpkgs already gives you
    # exact-pinned toolchains via pkgs.rustc/pkgs.cargo or the `fenix`/
    # `rust-overlay` flakes), but it's included verbatim since that's the
    # explicit goal here. It also matches modules/zsh.nix, which already
    # sources "$HOME/.cargo/env" verbatim from the old Arch zshenv — that
    # file is what `rustup-init` creates, so keeping rustup (rather than
    # swapping in pkgs.rustc/pkgs.cargo) is what actually keeps that line
    # working after `rustup-init` is re-run on the new box.
    rustup
    rustlings
    sccache

    # ── JVM ─────────────────────────────────────────────────────────────
    jdk11
    jdk21

    # ── JS/TS ───────────────────────────────────────────────────────────
    # nodejs_20 is currently only pulled in as neovim's Node provider
    # (home/modules/neovim.nix, programs.neovim.withNodeJs) and isn't
    # guaranteed to land on $PATH for general shell use, so it's added
    # here explicitly too (also gives you `npm` for free).
    nodejs
    bun
    pnpm
    # nvm has no nixpkgs package (and doesn't really make sense under Nix,
    # which pins Node versions directly rather than switching them at
    # runtime) — intentionally skipped; use `nodejs` above, or add another
    # nodejs_XX alongside it if you need a second pinned version.

    # ── Lua ─────────────────────────────────────────────────────────────
    lua5_1  # lua51
    lua5_2  # lua52
    lua5_4  # lua54
    luarocks
    lua51Packages.luacheck  # luacheck has no flat top-level attr; it only
                            # lives inside the per-version lua package sets

    # ── Sass ────────────────────────────────────────────────────────────
    dart-sass

    # ── Embedded / keyboard firmware ────────────────────────────────────
    arduino-cli
    qmk

    # ── Git extras / VCS ────────────────────────────────────────────────
    # (git itself is already a system package via configuration.nix)
    git-filter-repo
    git-lfs
    mercurial

    # ── Static site / docs ──────────────────────────────────────────────
    hugo
    pandoc  # pandoc-cli's functionality now lives in this attr directly
            # (pandoc >=3.0 builds the CLI binary from the pandoc-cli
            # package internally); there's no separate pandoc-cli attr

    # ── Browser automation / testing ────────────────────────────────────
    geckodriver
    playwright  # = playwright-driver: bundles the CLI + managed browsers

    # ── Android SDK / tooling ────────────────────────────────────────────
    # Deliberately NOT setting up pkgs.androidenv.androidPkgs.androidsdk
    # here (the flat android-sdk / android-sdk-build-tools names from Arch
    # don't exist in nixpkgs — that's a composition you build by picking
    # exact platform/build-tools versions, not a package lookup). More
    # importantly: home/zsh/scripts/android-spawn.sh already hardcodes
    # ANDROID_SDK_ROOT=/opt/android-sdk and launches
    # /opt/android-sdk/emulator/emulator directly, which is an existing,
    # working, non-Nix SDK install this system already depends on (see the
    # CakePhone AVD setup from prior work). Adding a parallel Nix-built SDK
    # here risks a second, conflicting ANDROID_SDK_ROOT and duplicated
    # multi-GB downloads for no benefit. Only adding the standalone adb/
    # fastboot CLI, which doesn't touch that setup:
    android-tools  # adb, fastboot (standalone; not the full licensed SDK)
  ];
}
