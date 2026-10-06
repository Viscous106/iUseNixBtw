{ config, lib, pkgs, ... }:

# ── Solidity / EVM development environment ───────────────────────────────────
# Spec: docs/superpowers/specs/2026-09-27-web3-dev-environment-design.md
#
# This owns everything Solidity-related that used to live as a bare package list
# in dev-toolchains.nix. It is the one options-driven module in this config
# (everything else is plain `config`), because the whole point here is that the
# toolchain gets retuned from this file rather than by editing files inside
# individual projects.
#
# Three things it exists to fix:
#
#   1. nixpkgs ships a single solc (0.8.33). Older course material needs 0.6.x.
#      `solc.extra` pins as many additional compilers as wanted, each installed
#      as `solc-<version>` so they coexist. See pkgs/solc-bin.nix.
#
#   2. Nothing switched toolchains on `cd`. direnv + nix-direnv does, and
#      home/modules/git.nix already gitignores .direnv/.envrc — this config
#      anticipated direnv before it was installed. starship.toml likewise
#      already has a [direnv] prompt module.
#
#   3. Every new project meant hand-writing foundry.toml and re-remembering
#      non-obvious flags. `web3-cli` stamps out a correct project instead.

let
  cfg = config.my.web3;

  # Compilers named solc-<version>, from upstream's static release binaries.
  extraSolcPkgs =
    lib.mapAttrsToList (version: sha256: pkgs.solc-bin { inherit version sha256; })
      cfg.solc.extra;

  # Absolute path to whichever compiler `solc.default` names. Foundry reads this
  # via FOUNDRY_SOLC, which means no project's foundry.toml ever has to hardcode
  # a store path (verified: `forge config` reports the env-supplied compiler).
  defaultSolcPath =
    if cfg.solc.default == "nixpkgs" then
      "${pkgs.solc}/bin/solc"
    else
      "${pkgs.solc-bin {
        version = cfg.solc.default;
        sha256  = cfg.solc.extra.${cfg.solc.default};
      }}/bin/solc-${cfg.solc.default}";

  # The project skeleton `web3-cli` copies. Kept out-of-store as a plain
  # directory in this repo so it can be edited without a rebuild round-trip.
  templateDir = ../web3/template;

  web3-cli = pkgs.writeShellApplication {
    name = "web3-cli";
    runtimeInputs = [ pkgs.coreutils pkgs.git pkgs.direnv ];
    text = ''
      if [ $# -lt 1 ]; then
        echo "usage: web3-cli <directory>" >&2
        echo "" >&2
        echo "Creates a Foundry project with flake.nix, .envrc, justfile and a" >&2
        echo "correct foundry.toml. Pick the compiler by editing solcVersion in" >&2
        echo "the generated flake.nix." >&2
        exit 64
      fi

      dest="$1"
      if [ -e "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
        echo "web3-cli: $dest exists and is not empty, refusing to overwrite" >&2
        exit 1
      fi

      mkdir -p "$dest"
      cp -rT ${templateDir} "$dest"
      # Store files land read-only; make the new project writable.
      chmod -R u+w "$dest"

      # .envrc is written here rather than shipped in templateDir on purpose.
      # home/modules/git.nix gitignores ".envrc" globally, so a template copy
      # never gets git-added — and a flake only copies *tracked* files into the
      # store, so the template in the store would silently lack it and direnv
      # would never load. Generating it sidesteps that entirely.
      printf '%s\n' \
        '# Loads the dev shell from flake.nix on cd. Run: direnv allow (once).' \
        'use flake' > "$dest/.envrc"

      echo "Created $dest"

      # A flake can only see git-tracked files. Created inside an existing repo,
      # flake.nix is invisible to nix and direnv fails with "Path ... is not
      # tracked by Git" on the first cd. Staging it here removes a step that
      # has no judgement in it. Projects outside any repo skip this.
      if repo=$(git -C "$dest" rev-parse --show-toplevel 2>/dev/null); then
        rel=$(realpath --relative-to="$repo" "$dest")
        if git -C "$repo" add "$rel" 2>/dev/null; then
          echo "  staged in $repo"
        else
          echo "  WARNING: could not stage $rel -- run 'git -C $repo add $rel'" >&2
          echo "           or the dev shell will not load." >&2
        fi
      fi

      # Trusting an .envrc this command just wrote itself adds no risk the user
      # has not already taken by running this command.
      if command -v direnv >/dev/null 2>&1; then
        if direnv allow "$dest" 2>/dev/null; then
          echo "  direnv allowed"
        else
          echo "  WARNING: 'direnv allow' failed -- run it inside the project." >&2
        fi
      fi

      echo ""
      echo "Next:"
      # Changing the parent shell's directory is impossible from a child
      # process, so this one step stays manual. The zsh wrapper defined in this
      # same module does it for interactive use.
      echo "  cd $dest"
      echo "  just test"
    '';
  };
in
{
  options.my.web3 = {
    enable = lib.mkEnableOption "the Solidity/EVM development environment";

    solc = {
      default = lib.mkOption {
        type = lib.types.str;
        default = "nixpkgs";
        description = ''
          Compiler used when a shell does not pin its own. Either the literal
          string "nixpkgs" (whatever pkgs.solc currently is, flake-locked) or a
          version key present in `solc.extra`. Anything else fails the build.
        '';
        example = "0.6.12";
      };

      extra = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = ''
          Additional compilers to install, as version -> sha256 of that
          release's `solc-static-linux` asset. Each is installed as
          `solc-<version>`, so they never collide with each other or pkgs.solc.

          Get a hash with:
            nix-prefetch-url https://github.com/ethereum/solidity/releases/download/v<VER>/solc-static-linux
        '';
        example = {
          "0.6.12" = "f6cb519b01dabc61cab4c184a3db11aa591d18151e362fcae850e42cffdfb09a";
        };
      };
    };

    direnv.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install direnv + nix-direnv and hook them into zsh, so entering a
        project directory loads that project's dev shell automatically.
      '';
    };

    anvil.port = lib.mkOption {
      type = lib.types.port;
      default = 8545;
      description = ''
        Port the generated justfile's `node` and `deploy` recipes use for the
        local anvil chain.
      '';
    };

    extraTools = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to install alongside the EVM toolchain.";
      example = lib.literalExpression "with pkgs; [ slither-analyzer ]";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.solc.default == "nixpkgs" || cfg.solc.extra ? ${cfg.solc.default};
        message = ''
          my.web3.solc.default is "${cfg.solc.default}", which is neither
          "nixpkgs" nor a key of my.web3.solc.extra. Add that version to
          `extra` (with its sha256), or set `default = "nixpkgs"`.
        '';
      }
    ];

    home.packages = [
      # forge/cast/anvil/chisel, built from source via rustPlatform and pinned
      # by the flake lock — moved here from dev-toolchains.nix.
      pkgs.foundry
      # Bare `solc` on PATH, for tooling that shells out to it directly.
      pkgs.solc
      # Task runner for the generated justfile.
      pkgs.just
      web3-cli
    ] ++ extraSolcPkgs ++ cfg.extraTools;

    home.sessionVariables = {
      # Makes `forge` outside any project shell use the configured default
      # rather than trying to download one into ~/.svm. Project shells override
      # it with their own pinned compiler.
      FOUNDRY_SOLC = defaultSolcPath;

      # Read by the generated justfile, so the anvil port lives in this config
      # instead of being duplicated into every project.
      WEB3_ANVIL_PORT = toString cfg.anvil.port;
    };

    programs.direnv = lib.mkIf cfg.direnv.enable {
      enable = true;
      # Caches the dev shell so `cd` into a project is not a full nix evaluation
      # every time.
      nix-direnv.enable = true;
    };

    # web3-cli stages the project and allows direnv itself, but no child process
    # can change its parent shell's working directory — so the final `cd` can
    # only come from a shell function. Shadowing the command name (the same
    # trick cp/mv/cd already use in zsh.nix) keeps it to one thing to remember.
    programs.zsh.initContent = ''
      web3-cli() {
        command web3-cli "$@" || return
        local dest=''${@[-1]}
        [[ -d $dest ]] && cd $dest
      }
    '';
  };
}
