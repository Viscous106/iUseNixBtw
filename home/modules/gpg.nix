{ config, pkgs, ... }:

{
  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-qt;
    enableSshSupport = true;
    
    # Increase cache TTL to 2 hours (7200 seconds)
    defaultCacheTtl = 7200;
    maxCacheTtl = 7200;
  };
}
