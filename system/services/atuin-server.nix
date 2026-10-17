{ ... }:

# Self-hosted Atuin sync server for home/shell/atuin.nix (no reliance on the
# hosted service's unwritten limits). Runs on both hosts, each syncing to localhost;
# creates its own database in the shared postgres.

{
  services.atuin = {
    enable = true;

    # Bind everywhere rather than the tailnet IP (no tailscaled ordering dependency);
    # the firewall limits access to loopback and tailscale0.
    host = "0.0.0.0";
    port = 8888;
    openFirewall = false;

    # TEMPORARY: set to false once both hosts have run `atuin register`.
    openRegistration = false;

    # Default 8192 silently drops longer commands.
    maxHistoryLength = 65536;
  };

  # No TLS/proxy on purpose: traffic is tailnet-only (WireGuard) and E2E encrypted.
}
