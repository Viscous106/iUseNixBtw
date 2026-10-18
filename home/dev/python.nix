{ pkgs, ... }:

# System Python for quick scripts and the Jupyter kernel molten uses in nvim.
# Projects get their own environments through uv. (nvim's pynvim env is in neovim.nix.)
let
  pythonWithLibs = pkgs.python3.withPackages (ps: with ps; [
    ipykernel
    jupyter-client
    jupyter-console
    notebook
    pandas
    numpy
    requests
  ]);
in
{
  home.packages = [
    pythonWithLibs
    pkgs.uv
    pkgs.python3Packages.pip  # no top-level pkgs.pip
  ];
}
