{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;

    # Using the modern 'settings' block to avoid warnings
    settings = {
      user = {
        name  = "Yash Nitin Virulkar";
        email = "virulkaryashed@gmail.com";
        signingkey = "~/.ssh/id_ed25519";
      };

      # ── Signing Settings ──────────────────────────────────────────────────
      gpg.format = "ssh";
      gpg.ssh.program = "${config.home.homeDirectory}/.config/hypr/scripts/git-sign-no-agent.sh";
      commit.gpgsign = true;           # Force signing on every commit
      tag.gpgsign = true;              # Force signing on every tag
      
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";

      # ── Basic Git Settings ────────────────────────────────────────────────
      init.defaultBranch   = "main";
      pull.rebase          = true;
      push.autoSetupRemote = true;
      rerere.enabled       = true;

      core = {
        editor   = "nvim";
        autocrlf = "input";
      };

      # Use SSH instead of HTTPS
      "url \"git@github.com:\"".insteadOf = "https://github.com/";
    };

    ignores = [ ".direnv" ".envrc" "*.swp" "node_modules" ];
  };

  # Delta handles its own package installation
  programs.delta = {
    enable = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "Catppuccin Mocha";
    };
  };

  home.packages = with pkgs; [ 
    # Delta is already included via programs.delta above
  ];
}
