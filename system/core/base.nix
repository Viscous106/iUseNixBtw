{ pkgs, ... }:

{
  time.timeZone      = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.zsh.enable = true;

  # Set for every session, including Hyprland started from the TTY.
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Cap the journal: a driver warning storm once grew it to 3 GB.
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    SystemMaxFileSize=50M
    MaxRetentionSec=1month
  '';

  # No core dumps (xdg-desktop-portal-hyprland segfaults on teardown). Without systemd-coredump the kernel
  # writes plain cores, so soft limits are zeroed too; the hard limit stays for `ulimit -c unlimited`.
  systemd.coredump.enable = false;
  systemd.settings.Manager.DefaultLimitCORE = "0:infinity";
  systemd.user.settings.Manager.DefaultLimitCORE = "0:infinity";
  security.pam.loginLimits = [
    { domain = "*"; item = "core"; type = "soft"; value = "0"; }
  ];

  system.stateVersion = "25.05";
}
