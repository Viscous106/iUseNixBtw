{ pkgs, ... }:

# ── Neovim's *external* dependencies ───────────────────────────────────────
#
# This file audits the LIVE Arch config at ~/.config/nvim (a kickstart.nvim
# fork: init.lua + lua/kickstart/plugins/{debug,neo-tree}.lua actually
# `require`d, plus lua/custom/plugins/init.lua) against nixpkgs, and adds
# whatever it needs that isn't already declared anywhere else in this repo.
#
# IMPORTANT CONTEXT for whoever reviews this — see the accompanying report
# for the full breakdown, but the short version:
#
#   1. Nearly every LSP server / DAP adapter / formatter the live config uses
#      (jdtls, codelldb, delve, gopls, lua_ls, typescript-language-server,
#      stylua) is installed by mason.nvim/mason-tool-installer at runtime
#      into ~/.local/share/nvim/mason — NOT via pacman, and not via nixpkgs.
#      Mason is self-contained: it downloads its own copies regardless of
#      the host OS/package manager, so it will attempt to do the exact same
#      thing on this NixOS box. Declaring nixpkgs equivalents of those same
#      tools here would NOT actually get used (mason prepends its own bin
#      dir to $PATH ahead of anything else), so this file deliberately does
#      NOT re-declare jdt-language-server / codelldb / delve / stylua /
#      lua-language-server / typescript-language-server as packages.
#
#   2. The one thing that DOES matter and is NOT something this file (a
#      home-manager module) can fix: mason downloads prebuilt, dynamically
#      linked binaries that expect an FHS-style dynamic loader
#      (/lib64/ld-linux-x86-64.so.2 etc.), which a default NixOS install does
#      not provide. Nowhere in this repo is `programs.nix-ld.enable = true;`
#      set (checked: no hits for nix-ld anywhere). Without it, mason-fetched
#      *native* binaries — most riskily codelldb (bundles liblldb.so) and
#      lua-language-server (C++ binary), and to a lesser extent stylua (Rust)
#      — are likely to fail to execute at all. gopls/delve (pure static Go)
#      and typescript-language-server/jdtls (run via node/java, no ELF
#      loader issue) are much lower risk. This is a `configuration.nix`
#      change (`programs.nix-ld.enable = true;`), which is out of scope for
#      this file — flagged for review instead of silently worked around.
#
# What IS added below are the pieces that are genuinely absent from the repo
# and that mason can't substitute for, because they're either build tools
# mason/plugins shell out to, or standalone CLI programs the config invokes
# directly.

{
  home.packages = with pkgs; [
    # ── Build toolchain ───────────────────────────────────────────────────
    # Nothing in the repo currently exposes a C compiler or `make` on PATH
    # (environment.systemPackages in configuration.nix is just
    # git/curl/wget/vim/btrfs-progs/... — no gcc/gnumake). The live config
    # needs both for:
    #   - telescope-fzf-native.nvim's `build = 'make'` step (native fzf lib)
    #   - LuaSnip's `build = 'make install_jsregexp'` step (compiles a C
    #     extension for regex-based snippets)
    #   - nvim-treesitter (branch = 'main') compiling generated parser .c
    #     files into loadable .so's at :TSUpdate / ensure_installed time
    #   - nvim-gdb's `build = ':!./install.sh'`
    gcc
    gnumake

    # ── unzip ─────────────────────────────────────────────────────────────
    # kickstart's own lua/kickstart/health.lua checks for `unzip` explicitly
    # (alongside git/make/rg) as a baseline requirement — mason also shells
    # out to it for .zip-packaged tools. Not declared anywhere else.
    unzip

    # ── gdb ───────────────────────────────────────────────────────────────
    # lua/custom/plugins/init.lua wires up sakhnik/nvim-gdb for assembly-
    # level debugging (<leader>db / <leader>da). This is a plain system gdb
    # invocation (`GdbStart gdb -q ...`), not something mason manages, and
    # `gdb` is not declared anywhere else in the repo.
    gdb

    # ── yarn ──────────────────────────────────────────────────────────────
    # iamcco/markdown-preview.nvim's build step is
    # `cd app && yarn install --frozen-lockfile`. nodejs/npm are already
    # covered (home/modules/dev-toolchains.nix `nodejs`, and this repo's
    # neovim.nix `nodejs_20`), but yarn specifically is not declared
    # anywhere, and npm cannot substitute for a yarn-locked install.
    yarn
  ];
}
