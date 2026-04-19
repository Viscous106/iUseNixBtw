{ config, pkgs, ... }:

{
  programs.git = {
    enable    = true;
    userName  = "viscous";
    userEmail = "your@email.com";   # change this or use /persist/secrets/git-identity

    extraConfig = {
      init.defaultBranch      = "main";
      pull.rebase             = true;
      push.autoSetupRemote    = true;
      core.editor             = "nvim";
      core.autocrlf           = "input";
      merge.tool              = "nvimdiff";
      diff.tool               = "nvimdiff";
      rerere.enabled          = true;   # reuse recorded conflict resolutions

      # Use SSH instead of HTTPS for GitHub/GitLab
      "url \"git@github.com:\"".insteadOf  = "https://github.com/";
      "url \"git@gitlab.com:\"".insteadOf  = "https://gitlab.com/";
    };

    delta = {
      enable  = true;
      options = {
        navigate     = true;
        side-by-side = true;
        dark         = true;
        line-numbers = true;
        syntax-theme = "Catppuccin Mocha";
      };
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

    aliases = {
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
  };

  home.packages = with pkgs; [ git-delta ];
}
