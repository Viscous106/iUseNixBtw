{ config, pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  # ── AI coding agents ──────────────────────────────────────────────────────
  home.packages = [
    pkgs.claude-code                                # pinned via the nixpkgs-claude input (flake.nix)
    pkgs.claude-whoami                              # which Anthropic org/workspace Claude Code uses
    inputs.codex-cli-nix.packages.${system}.codex   # native Codex CLI, not the node wrapper
    pkgs.codex-whoami                               # which OpenAI org/project Codex bills
    inputs.antigravity.packages.${system}.google-antigravity-ide
    inputs.antigravity.packages.${system}.google-antigravity-cli  # `agy`
    pkgs.goose-cli           # Block's agent (bare `goose` is an unrelated migration tool)
    pkgs.opencode
    pkgs.github-copilot-cli  # `copilot` binary (`copilot-cli` is AWS's ECS tool)
  ];

  # Linked into the repo directly: Claude's atomic rewrite fails if the first symlink hop is in the store.
  # Skills/agents/commands come from the separate claude-skills repo (setup.md).
  home.activation.linkClaudeSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p $HOME/.config/claude
    $DRY_RUN_CMD ln -sfn /persist/nixos-config/dotfiles/claude/settings.json $HOME/.config/claude/settings.json
  '';
}
