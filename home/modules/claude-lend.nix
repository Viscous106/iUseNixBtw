{ config, inputs, ... }:

# ── claude-lend — lend metered Claude access without lending the credential ──
# A gateway on 127.0.0.1:8787 that swaps this account's Claude token into each
# guest request, meters it, and cuts guests off at their budget. Source and
# docs live in ~/Viscous/I-have-claude-BTW (flake input `claude-lend`).
#
# A user service, not a system one, so the token stays readable by exactly
# this account. Puts `claude-lend` on PATH (grant / status / revoke / doctor).
#
# One-time, before the first switch:
#
#   claude setup-token > ~/.config/claude-lend-token
#   chmod 600 ~/.config/claude-lend-token
#
# To lend it out over the tailnet: `tailscale serve --bg 8787`, then
# `claude-lend grant`.
{
  imports = [ inputs.claude-lend.homeManagerModules.default ];

  services.claude-lend = {
    enable = true;
    port   = 8787;

    # A string, not a path literal — a path would copy the secret into the
    # world-readable Nix store. Long-lived and separate from the interactive
    # session, so revoking it never signs this machine out of Claude Code.
    tokenFile = "${config.home.homeDirectory}/.config/claude-lend-token";

    # verbose = true;   # log every billed request to the journal

    # HTTPS on 8443, all interfaces, for guests on the same Wi-Fi. The gateway
    # runs its own CA; a LAN grant's message saves it on the guest's machine.
    # The firewall port is opened in configuration.nix (home-manager can't).
    lan.enable = true;
    lan.port   = 8443;
  };
}
