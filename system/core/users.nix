{ pkgs, user, ... }:

{
  # Account details come from identity.nix (setup.sh rewrites it on install).
  users.users.${user.username} = {
    isNormalUser = true;
    shell        = pkgs.zsh;
    extraGroups  = [ "wheel" "networkmanager" "video" "audio" "input" ];
    # Applied only when the account is created, so `passwd` keeps working.
    initialHashedPassword = user.hashedPassword;
  };

  security.sudo.wheelNeedsPassword = false;
}
