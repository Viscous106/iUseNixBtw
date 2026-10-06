{ ... }:

# Atuin sync server — the self-hosted half of the shell-history setup whose
# client lives in home/modules/atuin.nix.
#
# Why self-hosted rather than the hosted api.atuin.sh: the hosted service is
# free today and publishes no caps, but nothing is committed in writing — the
# only written promise on atuin.sh is "Atuin AI is free while in testing".
# The server is MIT-licensed and in the same repo as the client, so running it
# here removes the question of future limits permanently. Sync is end-to-end
# encrypted either way, so this is about control, not privacy.
#
# Costs no new infrastructure: database.createLocally (default true) appends
# "atuin" to services.postgresql.ensureDatabases and adds an owning user of
# the same name. Postgres is already enabled for both hosts in
# modules/apps-databases.nix, and this does not disturb its postgis/pgvector
# extension set.
#
# This module is in commonModules, so BOTH installs run a server and each
# host's client syncs to its own localhost. That keeps the flake.nix invariant
# that the only difference between the two installs is which
# hardware-configuration is appended. Pointing one host at the other over the
# tailnet later is a one-line sync_address change in the client module; the
# then-redundant server can simply stay running.

{
  services.atuin = {
    enable = true;

    # 0.0.0.0, not the tailnet IP. Binding a specific Tailscale address would
    # hardcode an IP that can change and would make this unit depend on
    # tailscaled having come up first — a well-known source of
    # failed-to-start-at-boot grief. Binding everywhere and letting the
    # firewall be the gate is the same trade configuration.nix already makes
    # for sshd (see the openFirewall = false reasoning there): the service
    # listens broadly, and only tailscale0 — a trusted interface per
    # networking.firewall.trustedInterfaces — plus loopback can actually reach it.
    host = "0.0.0.0";
    port = 8888;
    openFirewall = false;

    # ⚠ TEMPORARY — set back to false once both hosts have registered.
    #
    # This gates ALL signups, not just untrusted ones, so it has to be open
    # for the one `atuin register` per host and then closed again. It is left
    # true here only because the accounts have not been created yet; the
    # exposure while it is true is loopback plus tailscale0, which is the only
    # interface the firewall trusts.
    #
    #   1. rebuild with this true
    #   2. atuin register -u <user> -e <email>
    #   3. atuin key   <- save it, it is the E2E key and is unrecoverable
    #   4. set this to false and rebuild again
    openRegistration = true;

    # The module default is 8192 characters, and the server silently rejects
    # anything longer. Plenty of real commands here are longer than that —
    # nixos-rebuild invocations, long nix expressions, pasted one-liners — and
    # a dropped entry is invisible until you go looking for it.
    maxHistoryLength = 65536;
  };

  # No reverse proxy and no TLS on purpose. Atuin deprecated its built-in TLS
  # and recommends nginx/Caddy/Traefik in front, but that advice is for
  # internet-exposed servers. Everything reaching this one arrives over
  # WireGuard via Tailscale, and atuin's payloads are end-to-end encrypted on
  # top of that, so plain HTTP on the tailnet is already encrypted twice.
}
