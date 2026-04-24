{ config, pkgs, ... }:

{
  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
    
    # These settings force GPG to ask for your password almost every time
    defaultCacheTtl = 1;
    maxCacheTtl = 1;
  };
}
