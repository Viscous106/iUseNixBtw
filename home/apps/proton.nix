{ pkgs, ... }:

{
  # Proton apps; the Drive mount is a system unit (system/services/proton-drive.nix).
  home.packages = with pkgs; [
    proton-vpn            # drives NetworkManager over D-Bus, no module needed
    proton-vpn-cli
    proton-pass
    proton-authenticator
    rclone                # `rclone config` sets up the Drive remote
  ];
}
