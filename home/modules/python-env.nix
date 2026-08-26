# Python library ecosystem migrated from Arch's explicitly-installed python-* packages.
#
# NOTE on coexistence: this file adds a THIRD python resolution path alongside
# whatever is already in home/viscous.nix (a bare `pkgs.python3` and `pyenv`).
# `pythonWithLibs` below is its own self-contained interpreter + site-packages
# closure, entirely separate from the bare `python3` package and from any
# pyenv-managed interpreter/venvs. Concretely:
#   - bare `pkgs.python3`            -> a vanilla interpreter, stdlib only
#   - `pyenv`                        -> lets the user build/switch arbitrary
#                                        CPython versions + virtualenvs at will
#   - `pythonWithLibs` (this file)   -> one fixed interpreter with ALL the
#                                        libraries below permanently baked in
# All three will independently appear on PATH as their own `python3`/`python`.
# Whoever wires the imports together should decide whether that's acceptable
# (e.g. "system python has everything" is genuinely convenient) or whether
# pyenv/bare-python3 should be trimmed down once this is in place. Not
# reconciled here on purpose, per the task split.
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

      # --- jupyter stack -----------------------------------------------
      # covers python-ipykernel, python-jupyter-client, jupyter-console,
      # jupyter-notebook (as the `notebook` attr). See report: top-level
      # pkgs.jupyter / pkgs.jupyter-console were deliberately NOT used here
      # (details in the accompanying report) so everything jupyter-related
      # stays inside this one interpreter closure instead of adding yet
      # another separate python env.
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

      # --- mov-cli support libraries (pulled in for python-devgoldyutils and
      # python-loguru-logging-intercept-git; see report for the mov-cli-test
      # caveat) ------------------------------------------------------------
      devgoldyutils
      loguru-logging-intercept
    ]
  );
in
{
  home.packages = [
    pythonWithLibs

    # Dev/env-management tools: deliberately kept OUT of withPackages above.
    # These are meta-tools for managing *other* python environments and
    # don't compose well baked into one fixed interpreter closure.
    pkgs.uv
    pkgs.poetry
    pkgs.pipx
    pkgs.virtualenv # top-level alias: toPythonApplication virtualenv
    pkgs.python3Packages.pip # no top-level `pkgs.pip` alias exists in nixpkgs;
    # this is the standard way to get a standalone `pip` binary.
  ];
}
