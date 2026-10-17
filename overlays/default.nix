# Package overrides and local packages, applied to both NixOS and home-manager
# (home-manager uses useGlobalPkgs).
inputs: final: prev: {
  # Hyprland from its flake, used by both programs.hyprland and home-manager.
  # wrapRuntimeDeps = false skips hyprland-guiutils, which fails to build
  # upstream (libstdc++ ABI mismatch). Hyprland 0.56 needs glaze 7.x;
  # nixpkgs has 8.x, so 7.2.0 is pinned for this build only.
  hyprland-pinned = inputs.hyprland.packages.${prev.stdenv.hostPlatform.system}.hyprland.override {
    wrapRuntimeDeps = false;
    glaze-hyprland = prev.glaze.overrideAttrs (old: {
      version = "7.2.0";
      src = prev.fetchFromGitHub {
        owner = "stephenberry";
        repo  = "glaze";
        rev   = "v7.2.0";
        hash  = "sha256-f3NVRi3SXKo42hn0WCw7JsOK3EkdOVJIcuzhPorKjFY=";
      };
    });
  };

  # claude-code from its own pinned input so it can move faster than the
  # system snapshot (see nixpkgs-claude in flake.nix).
  claude-code = (import inputs.nixpkgs-claude {
    system = prev.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  }).claude-code;

  # Local packages (pkgs/).
  opera            = final.callPackage ../pkgs/opera.nix { };            # dropped from nixpkgs; repacks the official .deb
  wallpaper-picker = final.callPackage ../pkgs/wallpaper-picker.nix { }; # SUPER+W, docs/design/wallpaper-picker.md
  rope-select      = final.callPackage ../pkgs/rope-select.nix { };      # region selector for screenshot/record
  codex-whoami     = final.callPackage ../pkgs/codex-whoami.nix { };
  claude-whoami    = final.callPackage ../pkgs/claude-whoami.nix { };
  solc-bin         = final.callPackage ../pkgs/solc-bin.nix { };         # pinned solc builds for web3.nix

  # atuin with two local patches: stable row numbers in the search TUI
  # (alt-1..9 are unbound in home/shell/atuin.nix) and deduplicated results.
  # Not in the binary cache, so it builds locally; tests and opt-level are
  # cut to keep that build short. Drop this attr to go back to stock atuin.
  atuin = prev.atuin.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../pkgs/atuin-number-all-rows.patch
      ../pkgs/atuin-dedup-search-results.patch
    ];
    doCheck = false;
    CARGO_PROFILE_RELEASE_OPT_LEVEL = "1";
  });
}
