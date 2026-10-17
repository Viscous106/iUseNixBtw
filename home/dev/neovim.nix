{ config, pkgs, lib, ... }:

let
  # python3 provider for molten-nvim (a pynvim remote plugin; needs
  # :UpdateRemotePlugins before its :Molten* commands exist).
  nvimPythonEnv = pkgs.python3.withPackages (ps: with ps; [
    pynvim          # required — the Neovim remote-plugin API
    jupyter-client  # required — talks to Jupyter kernels
    ipykernel       # the Python kernel :MoltenInit actually starts
    nbformat        # :MoltenImportOutput / :MoltenExportOutput
    pillow          # :MoltenImagePopup
    cairosvg        # SVG outputs with transparency
    pyperclip       # g:molten_copy_output
  ]);

  # Unique name, not `python3`: extraPackages are --suffix'ed onto PATH so a
  # bare python3 would lose to the system one. init.lua finds it via exepath().
  nvimPythonHost = pkgs.writeShellScriptBin "nvim-python3-host" ''
    exec ${nvimPythonEnv}/bin/python3 "$@"
  '';
in

{
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;
    # Must stay false: enabling any provider makes home-manager generate
    # nvim/init.lua, colliding with the vendored dotfiles/nvim symlink.
    withNodeJs    = false;
    withPython3   = false;
    withRuby      = false;

    extraPackages = with pkgs; [
      # Runtimes needed by LSPs / plugin build steps
      nodejs        # unsuffixed: tracks current default, avoids future EOL pins
      python3
      nvimPythonHost # python3 provider for molten-nvim (see let-block above)
      # Fuzzy search (Telescope dependency)
      ripgrep
      fd
      git
      tree-sitter # CLI needed by nvim-treesitter to compile parsers
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

  home.packages = with pkgs; [
    # Plugin build steps: telescope-fzf-native, LuaSnip jsregexp, treesitter parsers
    gcc
    gnumake
    unzip # kickstart healthcheck + mason .zip packages
    gdb   # nvim-gdb
    yarn  # markdown-preview.nvim build (yarn.lock)
  ];

  # The neovim module always generates nvim/init.lua; force it off so it
  # doesn't collide with the vendored dotfiles/nvim tree (home/dotfiles.nix).
  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
}
