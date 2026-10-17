# The one Python: a single interpreter with the libraries baked in, plus pyenv
# for ad-hoc CPython versions. (Neovim's pynvim env is separate, in neovim.nix.)
{ pkgs, ... }:

let
  pythonWithLibs = pkgs.python3.withPackages (
    ps:
    with ps;
    [
      # --- web / app frameworks -------------------------------------------
      django
      fastapi
      streamlit

      # --- data / analytics ------------------------------------------------
      pandas
      duckdb
      geopandas

      # --- jupyter stack (kept inside this env, not pkgs.jupyter) ------
      ipykernel
      jupyter-client
      jupyter-console
      notebook

      # --- openai / nlp ------------------------------------------------
      openai
      tiktoken

      # --- http / scraping / validation ---------------------------------
      requests
      validators
      pyquery

      # --- linting -------------------------------------------------------
      flake8

      # --- auth / security -------------------------------------------------
      pyotp
      aiohttp-oauthlib

      # --- music / media API clients ---------------------------------------
      bandcamp-api
      soundcloud-v2
      spotipy
      syncedlyrics
      pytubefix

      # --- misc utilities --------------------------------------------------
      dacite
      python-decouple # nixpkgs kept the full "python-decouple" attr name
      demjson3
      inquirer
      thefuzz
      sounddevice

      # --- db migrations -----------------------------------------------
      alembic

      # --- mov-cli support libraries -------------------------------------
      devgoldyutils
      loguru-logging-intercept
    ]
  );
in
{
  home.packages = [
    pythonWithLibs

    # Environment managers stay outside withPackages.
    pkgs.pyenv  # initialised in home/zsh/scripts/variable.sh
    pkgs.uv
    pkgs.poetry
    pkgs.pipx
    pkgs.virtualenv # top-level alias: toPythonApplication virtualenv
    pkgs.python3Packages.pip  # no top-level pkgs.pip
  ];
}
