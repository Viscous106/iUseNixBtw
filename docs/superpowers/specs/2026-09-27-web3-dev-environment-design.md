# Declarative Solidity / EVM Development Environment

**Date:** 2026-09-27
**Status:** Draft, pending review

## Problem

`home/modules/dev-toolchains.nix` already installs `foundry` and `solc`, flake-locked, and
its comment explicitly reasons through why `foundryup` was rejected. That covers "the tools
exist on PATH" and nothing beyond it. Three gaps remain, all of which caused concrete
failures while following a Solidity course on 2026-09-27.

### Gap 1 — solc is a single global version

`nixpkgs` ships exactly one solc. Verified against the pinned input's source tree
(`/nix/store/4h2cj19n104pslz9qdd10km9gql80fkz-source`):

```
$ ls -d $NP/pkgs/by-name/so/solc*
/nix/store/4h2cj19n104pslz9qdd10km9gql80fkz-source/pkgs/by-name/so/solc

$ grep -n 'version' $NP/pkgs/by-name/so/solc/package.nix
28:  version = "0.8.33";
```

There are no `solc_0_6_x`-style attributes. Solidity is unusually version-sensitive — the
freeCodeCamp course targets `pragma solidity >=0.6.0 <0.9.0`, and older material pins 0.6.x
exactly. A single global compiler cannot serve both.

Foundry's own answer is to download solc into `~/.svm`, which the existing
`dev-toolchains.nix` comment already flags as the one non-reproducible corner of the setup.
It is also actively broken under a restricted filesystem:

```
Failed to install solc 0.8.31: Read-only file system (os error 30)
```

### Gap 2 — no per-directory environment

Nothing switches toolchains or sets project variables on `cd`. The practical consequence,
observed directly: a `foundry.toml` placed one directory above the contract made
`forge create` resolve paths against an unexpected project root.

```
$ forge create SingleStorage.sol:SimpleStorage --rpc-url $RPC --unlocked --from $ME --broadcast
Error: ".../web3/blockchain/freeCodeCamp/SingleStorage.sol": No such file or directory
```

Note that `forge build` resolves the same argument relative to the working directory while
`forge create` resolves it relative to the detected project root. That inconsistency is
invisible until it bites.

`home/modules/git.nix:33` already gitignores `.direnv` and `.envrc`, so the configuration
anticipated direnv, but direnv is not installed.

### Gap 3 — no project scaffold

Every new project means rewriting `foundry.toml`, `.gitignore`, and the `test/` layout by
hand, and re-remembering non-obvious flags. Both of these are required and neither is
guessable:

- `--broadcast` — without it `forge create` silently performs a dry run
- `--unlocked --from <addr>` — lets anvil sign, avoiding a 66-character private key on the
  command line, which wraps on paste and breaks

Build artifacts compound the problem: `out/` and `cache/` are currently **tracked** in the
notes repo, so every build dirties `git status`.

## Goal

A declarative, system-wide Solidity environment owned by this configuration and retuned by
editing module options — not by touching files inside individual projects. Entering a
project directory should provide exactly that project's toolchain, and creating a new
project should produce a correct layout on the first try.

## Verified findings

These were confirmed on this machine on 2026-09-27 and are load-bearing for the design.

### `FOUNDRY_SOLC` overrides the compiler per invocation

No absolute store path needs to be hardcoded in any `foundry.toml`:

```
$ FOUNDRY_SOLC=$(command -v solc) forge config | grep '^solc'
solc = "/etc/profiles/per-user/viscous/bin/solc"
```

### Official static solc binaries run unpatched on NixOS

This is the crucial finding. Unlike Foundry's `svm` downloads, the official Solidity Linux
release binaries are statically linked and need no `patchelf` or autoPatchelf wrapper:

```
$ curl -sSL -o solc612 https://github.com/ethereum/solidity/releases/download/v0.6.12/solc-static-linux
$ chmod +x solc612 && ./solc612 --version
solc, the solidity compiler commandline interface
Version: 0.6.12+commit.27d51765.Linux.g++

$ sha256sum solc612
f6cb519b01dabc61cab4c184a3db11aa591d18151e362fcae850e42cffdfb09a
```

Because the binary is content-addressable by hash and needs no patching, multi-version solc
can be a plain `fetchurl` derivation. **No extra flake input (`solc.nix`) and no imperative
version manager are required.**

`pkgs.solc-select` 1.2.0 also exists in nixpkgs and was verified to work, installing a
runnable 0.6.12 to `~/.solc-select/artifacts/`. It is **rejected** for this design: it
fetches at runtime into mutable home state, which is exactly the property this
configuration avoids elsewhere.

### End-to-end version pinning works

The same unmodified project compiles under either compiler, selected purely by environment:

```
$ FOUNDRY_SOLC=~/.solc-select/artifacts/solc-0.6.12/solc-0.6.12 forge build
Compiling 1 files with Solc 0.6.12
Compiler run successful!

$ FOUNDRY_SOLC=$(command -v solc) forge build --force
Compiling 1 files with Solc 0.8.33
Compiler run successful!
```

This is the whole mechanism. A dev shell that exports `FOUNDRY_SOLC` gives per-project
compiler pinning with no other moving parts.

### Soldeer is built into the installed Foundry

`forge soldeer install` is available, so dependencies such as `forge-std` can be fetched
without `forge install` creating git submodules — a meaningful benefit inside a notes repo
that should not grow submodules.

## Design

### Component 1 — `home/modules/web3.nix`

A new home-manager module following the style of `dev-toolchains.nix`. The full option
surface:

```nix
viscous.web3 = {
  enable = true;

  solc = {
    # Compiler used when a shell does not pin one. Either the literal
    # "nixpkgs" (currently 0.8.33, flake-locked) or any version key present
    # in `extra` below. Anything else is a build-time error.
    default = "nixpkgs";

    # Extra compilers, each a pinned fetchurl of the official static binary.
    # Attribute name is the version; value is the sha256 of that release.
    extra = {
      "0.6.12" = "f6cb519b01dabc61cab4c184a3db11aa591d18151e362fcae850e42cffdfb09a";
    };
  };

  direnv.enable = true;          # installs direnv + nix-direnv, adds the zsh hook
  projectRoot   = "~/Viscous/web3";

  anvil.port = 8545;             # used by the `just node` / `just deploy` recipes

  # Packages (not strings) added to every web3 dev shell.
  extraTools = with pkgs; [ slither-analyzer ];
};
```

Responsibilities:

1. Install `foundry`, the default `solc`, and `extraTools`.
2. Build a derivation per entry in `solc.extra` via `fetchurl` + `chmod +x`. No patching
   is needed (verified above). These are exposed so project flakes can reference them by
   version.
3. Export `FOUNDRY_SOLC` pointing at the default compiler, so bare `forge` invocations
   outside any project shell behave predictably.
4. When `direnv.enable`, install `direnv` + `nix-direnv` and add the zsh hook. The global
   gitignore already covers `.direnv`/`.envrc`.
5. Install the project template (component 2) into the Nix store and expose a way to
   instantiate it.

The solc entries move `dev-toolchains.nix`'s Solidity block into this module. That block
should be replaced with a pointer comment rather than left duplicated.

### Component 2 — project template

Instantiated into an empty directory to produce:

```
flake.nix        # dev shell; picks its solc version, sets FOUNDRY_SOLC
.envrc           # "use flake"
foundry.toml     # no absolute paths — compiler comes from the environment
justfile         # task runner, see below
.gitignore       # out/, cache/, .direnv/, broadcast/
src/ test/ script/
```

`foundry.toml` deliberately contains **no** `solc` key. Today's working file hardcodes
`/etc/profiles/per-user/viscous/bin/solc`, which is unshareable and breaks if the profile
path changes. The environment supplies it instead.

The template's `flake.nix` selects its compiler declaratively, e.g. a project following an
0.6-era course sets its version and gets 0.6.12 with no global change and no conflict with
any other project.

### Component 3 — `justfile`

Absorbs the flags that caused real failures:

| Recipe | Does |
|---|---|
| `just build` | `forge build` |
| `just test` | `forge test -vv` |
| `just node` | `anvil` on the configured port |
| `just deploy [VALUE]` | start anvil if absent, deploy, call `store`, print result |
| `just fmt` | `forge fmt` |

`just deploy` encapsulates `--broadcast`, `--unlocked --from`, `--rpc-url`, and the
deployed-address capture, so none of them must be recalled or pasted.

## Layout

```
~/Viscous/web3/
├── freeCodeCamp/        # flake pins solc 0.6.12
└── my-nft-thing/        # flake pins solc 0.8.33 — no conflict
```

Course code moves out of the notes repo into project directories. Notes stay prose; code
becomes a real project. This resolves the root cause of the Gap 2 failure, where a notes
repo was being used as a Foundry project root.

## Non-goals

- Hardhat / Truffle. Foundry only.
- Testnet deployment, key management, block-explorer verification. Local `anvil` only.
  Real-key handling deserves its own spec.
- Migrating existing notes-repo content beyond the one course directory in flight.
- Removing `out/`/`cache/` from git history. They should be untracked and gitignored going
  forward; rewriting history is out of scope.

## Risks

**Each `solc.extra` entry needs a hash.** Adding a version means recording its sha256.
Acceptable: it is the price of reproducibility, it is a one-line addition, and a wrong hash
fails loudly at build time rather than silently.

**Statically-linked-binary assumption.** Verified for 0.6.12. Very old releases (pre-0.4.x)
may not hold this property. Mitigation: the failure is immediate and obvious, and
`solc-select` remains an escape hatch.

**direnv adds shell startup cost.** `nix-direnv`'s caching is specifically designed for
this; the cost is paid once per project rather than per shell.

## Verification plan

Each must pass before this is considered done:

1. `nixos-rebuild switch` succeeds; `direnv` is on PATH and hooked into zsh.
2. Template instantiates into an empty directory; `forge build` succeeds with no
   `foundry.toml` edits.
3. `cd` into a project auto-loads the shell; `forge config | grep '^solc'` shows that
   project's pinned compiler, not the global one.
4. Two projects pinned to different solc versions each compile correctly, unchanged, in the
   same shell session.
5. `just deploy` completes: deploy, `store`, `status 1 (success)`, value read back.
6. `git status` is clean after a full build and test run.

## Open question for review

Whether course code should move to `~/Viscous/web3/` (as designed above) or stay inside the
`codingNotes` repo alongside its notes. The design assumes the former, since mixing a notes
repo with a Foundry project root is what produced the Gap 2 failure — but if notes and code
are deliberately kept together, the template needs to tolerate nesting and this section
needs revising.
