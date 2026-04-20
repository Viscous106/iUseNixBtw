{ config, pkgs, inputs, ... }:

{
  imports = [
    ./modules/zsh.nix
    ./modules/neovim.nix
    ./modules/hyprland.nix
    ./modules/hypridle.nix
    ./modules/waybar.nix
    ./modules/git.nix
    ./modules/kitty.nix
  ];

  home.username      = "viscous";
  home.homeDirectory = "/home/viscous";
  home.stateVersion  = "25.05";

  programs.home-manager.enable = true;

  # ── Symlink persisted SSH keys into ~/.ssh at every login ─────────────────
  home.activation.linkSecrets = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d /persist/secrets/ssh ]; then
      $DRY_RUN_CMD mkdir -p $HOME/.ssh
      $DRY_RUN_CMD ln -sf /persist/secrets/ssh/id_ed25519     $HOME/.ssh/id_ed25519     || true
      $DRY_RUN_CMD ln -sf /persist/secrets/ssh/id_ed25519.pub $HOME/.ssh/id_ed25519.pub || true
      $DRY_RUN_CMD chmod 700 $HOME/.ssh
      chmod 600 $HOME/.ssh/id_ed25519 2>/dev/null || true
    fi
  '';

  # ── XDG dirs ──────────────────────────────────────────────────────────────
  xdg.enable = true;
  xdg.userDirs = {
    enable            = true;
    createDirectories = true;
    setSessionVariables = true;
  };
}
