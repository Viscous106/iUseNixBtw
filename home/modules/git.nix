{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name  = "viscous";
        email = "your@email.com";   # change or use /persist/secrets/git-identity
      };

      init.defaultBranch   = "main";
      pull.rebase          = true;
      push.autoSetupRemote = true;
      rerere.enabled       = true;   # reuse recorded conflict resolutions

      core = {
        editor   = "nvim";
        autocrlf = "input";
      };

      merge.tool = "nvimdiff";
      diff.tool  = "nvimdiff";

      alias = {
        st  = "status -sb";
        lg  = "log --oneline --graph --all --decorate";
        pu  = "push";
        puf = "push --force-with-lease";
        co  = "checkout";
        br  = "branch";
        aa  = "add -A";
        ca  = "commit --amend --no-edit";
        wip = "!git add -A && git commit -m 'wip: checkpoint'";
      };

      # Use SSH instead of HTTPS for GitHub/GitLab
      "url \"git@github.com:\"".insteadOf = "https://github.com/";
      "url \"git@gitlab.com:\"".insteadOf = "https://gitlab.com/";
    };

    ignores = [
      ".direnv"
      ".envrc"
      "*.DS_Store"
      "*.swp"
      "*.swo"
      ".idea"
      "*.iml"
      ".vscode"
      "node_modules"
    ];
  };

  # delta is now a top-level HM program, separate from programs.git
  programs.delta = {
    enable               = true;
    enableGitIntegration = true;
    options = {
      navigate     = true;
      side-by-side = true;
      dark         = true;
      line-numbers = true;
      syntax-theme = "Catppuccin Mocha";
    };
  };

  home.packages = with pkgs; [ delta ];
}
