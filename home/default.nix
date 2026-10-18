{ config, lib, pkgs, inputs, user, ... }:

{
  # Every .nix file under home/ is imported.
  imports = [
    inputs.hyprland.homeManagerModules.default
    inputs.nix-index-database.homeModules.nix-index
  ] ++ import ../lib/import-dir.nix lib ./.;

  home.username      = user.username;
  home.homeDirectory = "/home/${user.username}";
  home.stateVersion  = "25.05";
  programs.home-manager.enable = true;

  # Solidity / EVM toolchain knobs (options in home/dev/web3.nix,
  # design in docs/design/web3-dev-environment.md).
  my.web3 = {
    enable = true;

    solc = {
      # Bare `forge`/`solc` outside a project shell use this one.
      default = "nixpkgs";

      # Extra compilers, each installed as solc-<version> so they coexist.
      # 0.6.12 is here for the freeCodeCamp course, which targets 0.6.x.
      extra = {
        "0.6.12" = "f6cb519b01dabc61cab4c184a3db11aa591d18151e362fcae850e42cffdfb09a";
      };
    };

    direnv.enable = true;
    anvil.port    = 8545;
  };

  # Hyprland's exec'd children don't get the interactive shell PATH.
  home.sessionPath = [
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
  ];

  xdg.enable = true;
  xdg.userDirs = {
    enable              = true;
    createDirectories   = true;
    setSessionVariables = true;
  };

  # Link persisted secrets (/persist/secrets) into $HOME.
  home.activation.linkSecrets = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    # Ensure /persist/secrets exists or create a dummy structure for portability
    if [ ! -d /persist/secrets ]; then
       echo "Warning: /persist/secrets not found. Creating dummy structure for portability."
       $DRY_RUN_CMD mkdir -p /persist/secrets/ssh
       $DRY_RUN_CMD touch /persist/secrets/git-identity
       $DRY_RUN_CMD touch /persist/secrets/claude_api
       $DRY_RUN_CMD touch /persist/secrets/openai_api
       $DRY_RUN_CMD echo "# Add your git config here" > /persist/secrets/git-identity
       $DRY_RUN_CMD echo "# export CLAUDE_CODE_OAUTH_TOKEN=your_token_here" > /persist/secrets/claude_api
       $DRY_RUN_CMD echo "# export OPENAI_API_KEY=your_key_here" > /persist/secrets/openai_api
    fi

    # SSH keys and known_hosts
    if [ -d /persist/secrets/ssh ]; then
      $DRY_RUN_CMD mkdir -p $HOME/.ssh
      $DRY_RUN_CMD chmod 700 $HOME/.ssh
      [ -f /persist/secrets/ssh/id_ed25519 ]     && $DRY_RUN_CMD ln -sf /persist/secrets/ssh/id_ed25519     $HOME/.ssh/id_ed25519     || true
      [ -f /persist/secrets/ssh/id_ed25519.pub ] && $DRY_RUN_CMD ln -sf /persist/secrets/ssh/id_ed25519.pub $HOME/.ssh/id_ed25519.pub || true
      [ -f /persist/secrets/ssh/known_hosts ]   && $DRY_RUN_CMD ln -sf /persist/secrets/ssh/known_hosts   $HOME/.ssh/known_hosts   || true
    fi
  '';
}
