{ config, inputs, ... }:

# claude-lend: metered Claude gateway on :8787 (flake input, ~/Viscous/I-have-claude-BTW).
# User service so only this account can read the token. One-time setup:
#   claude setup-token > ~/.config/claude-lend-token && chmod 600 ~/.config/claude-lend-token
{
  imports = [ inputs.claude-lend.homeManagerModules.default ];

  services.claude-lend = {
    enable = true;
    port   = 8787;

    # String, not a path: a path literal would copy the secret into the store.
    tokenFile = "${config.home.homeDirectory}/.config/claude-lend-token";

    # HTTPS for LAN guests; firewall port opened in system/network.nix.
    lan.enable = true;
    lan.port   = 8443;
  };
}
