{ config, pkgs, lib, ... }:

{
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;
    # withNodeJs/withPython3 disabled: home-manager's neovim module
    # unconditionally generates its own xdg.configFile."nvim/init.lua"
    # (setting vim.g.node_host_prog/python3_host_prog) whenever either is
    # true, which collides with the whole-directory vendored symlink for
    # "nvim" below (home/modules/extras.nix) — two entries claiming
    # overlapping paths. kickstart.nvim doesn't use the legacy Vim
    # node/python3 providers, so this is a clean drop, not a functional
    # loss. nodejs/python3 stay available via extraPackages for anything
    # that shells out to them directly (mason tools, build steps, etc.).
    withNodeJs    = false;
    withPython3   = false;
    withRuby      = false;

    extraPackages = with pkgs; [
      # Runtimes needed by LSPs / plugin build steps
      nodejs        # unsuffixed: tracks current default, avoids future EOL pins (nodejs_20 was removed)
      python3
      # Fuzzy search (Telescope dependency)
      ripgrep
      fd
      git
      # LSP servers — managed by Nix so they're always available
      lua-language-server
      nil                                    # Nix LSP
      nixd                                   # Alternative Nix LSP (better)
      typescript-language-server
      vscode-langservers-extracted           # html/css/json/eslint
      pyright                                # Python
      rust-analyzer
      gopls
      # Formatters / linters
      stylua
      shfmt
      prettier
      black
      isort
    ];
  };

  # home-manager's neovim module unconditionally generates
  # xdg.configFile."nvim/init.lua" (a provider-disable stub) whenever
  # programs.neovim.enable = true, no matter what other options are set —
  # this collides with the whole-directory vendored symlink for "nvim"
  # below (two entries claiming overlapping filesystem paths, which fails
  # at build time with "Error installing file '.config/nvim/init.lua'
  # outside $HOME"). Force it off; the real vendored init.lua is the only
  # one that should exist.
  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;

  # ── Real Arch config, vendored verbatim ─────────────────────────────────
  # This was a from-scratch hand-authored reimplementation of the spirit of
  # Arch's config (kickstart.nvim fork) rather than the actual config —
  # replaced with the real ~/.config/nvim tree (init.lua, lua/kickstart/,
  # lua/custom/, lazy-lock.json), live-editable at
  # /persist/nixos-config/home/nvim/, symlinked in home/modules/extras.nix.
  # lazy.nvim clones its 62 pinned plugins into
  # ~/.local/share/nvim/lazy/ on first launch (needs network), same as it
  # worked on Arch.
}
