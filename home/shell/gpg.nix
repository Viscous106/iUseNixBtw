{ config, pkgs, ... }:

{
  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
    # Off: programs.ssh.startAgent owns SSH_AUTH_SOCK; both on means the agent
    # you get depends on shell-init order.
    enableSshSupport = false;
    
    defaultCacheTtl = 7200;
    maxCacheTtl = 7200;
  };
}
