{ config, pkgs, ... }:

{
  programs.gpg = {
    enable = true;
  };

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
    # Arch's ~/.gnupg/gpg-agent.conf has NO enable-ssh-support, so gpg-agent is
    # not an SSH agent there. Enabling it here diverged from Arch *and* fought
    # with configuration.nix's `programs.ssh.startAgent = true`: both want to own
    # SSH_AUTH_SOCK (gpg-agent exports the gpgconf socket from the shell init,
    # NixOS exports $XDG_RUNTIME_DIR/ssh-agent from /etc/profile), so which agent
    # you got depended on shell-init ordering — and differed between apps launched
    # by Hyprland exec-once and apps launched from a terminal. Plain ssh-agent is
    # also what commit 44e4d6c set out to use.
    enableSshSupport = false;
    
    # Increase cache TTL to 2 hours (7200 seconds)
    defaultCacheTtl = 7200;
    maxCacheTtl = 7200;
  };
}
