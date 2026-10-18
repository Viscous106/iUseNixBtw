{ config, pkgs, inputs, ... }:

# Language toolchains & dev CLI tools. Solidity/EVM lives in home/dev/web3.nix.
{
  home.packages = with pkgs; [
    kind        # local kubernetes in docker
    kubectl
    vite
    # ── Go ──────────────────────────────────────────────────────────────
    go
    golangci-lint

    # ── Rust ────────────────────────────────────────────────────────────
    # rustup, not pkgs.rustc/cargo: zsh.nix sources ~/.cargo/env, which
    # rustup-init creates.
    rustup
    sccache

    # ── JVM ─────────────────────────────────────────────────────────────
    # Both ship bin/jar ("conflicting subpath"); jdk11 lowPrio so jdk21 wins.
    (pkgs.lib.lowPrio jdk11)
    jdk21

    # ── JS/TS ───────────────────────────────────────────────────────────
    # Shell nodejs/npm; neovim's extraPackages copy is only on nvim's PATH.
    nodejs
    bun
    pnpm

    # ── Lua ─────────────────────────────────────────────────────────────
    (pkgs.lib.setPrio 20 lua5_1)  # lua51 -- distinct low priority: lua5_1/5_2/5_4 all provide bin/lua, need a strict ranking, not tied lowPrio
    (pkgs.lib.lowPrio lua5_2)  # lua52 -- lower than default (lua5_4 wins), higher than lua5_1 above
    lua5_4  # lua54
    luarocks
    lua51Packages.luacheck  # no top-level attr

    # ── Sass ────────────────────────────────────────────────────────────
    dart-sass

    # ── Embedded / keyboard firmware ────────────────────────────────────
    arduino-cli

    # ── Git extras / VCS ────────────────────────────────────────────────
    git-filter-repo
    mercurial

    # ── Static site / docs ──────────────────────────────────────────────
    hugo
    pandoc  # includes the pandoc-cli binary

    # ── Browser automation / testing ────────────────────────────────────
    geckodriver
    playwright  # = playwright-driver: bundles the CLI + managed browsers

    # ── Android ──────────────────────────────────────────────────────────
    android-tools  # adb, fastboot (standalone; not the full licensed SDK)
  ];
}
