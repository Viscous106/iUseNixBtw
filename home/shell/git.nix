{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name  = "Yash Nitin Virulkar";
        email = "virulkaryashed@gmail.com";
        signingkey = "45A83CE1BF137274";
      };

      # ── Signing Settings (GPG) ────────────────────────────────────────────
      gpg.format = "openpgp"; # Switch back to GPG
      commit.gpgsign = true;
      tag.gpgsign = true;

      # ── Basic Git Settings ────────────────────────────────────────────────
      init.defaultBranch   = "main";
      pull.rebase          = true;
      push.autoSetupRemote = true;
      rerere.enabled       = true;

      core = {
        editor   = "nvim";
        autocrlf = "input";
      };

      "url \"git@github.com:\"".insteadOf = "https://github.com/";
    };

    ignores = [ ".direnv" ".envrc" "*.swp" "node_modules" ];
  };

  programs.delta = {
    enable = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "Catppuccin Mocha";
    };
  };
}
