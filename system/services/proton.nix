{ pkgs, ... }:

# ── Proton suite — VPN, Drive, Pass ──────────────────────────────
{
  # ── VPN ─────────────────────────────────────────────────────────────────────
  # No NixOS module: the proton-vpn app drives NetworkManager over D-Bus.

  # ── Drive ───────────────────────────────────────────────────────────────────
  # rclone protondrive. Type=notify hides the empty dir; SIGTERM unmounts; rclone.conf must stay writable (token refresh).
  systemd.services.protondrive-mount = {
    description = "Proton Drive (rclone FUSE mount)";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    wantedBy    = [ "multi-user.target" ];

    # Remote is created by `rclone config`; skip (not fail) until it exists.
    unitConfig = {
      ConditionPathExists = "/persist/secrets/rclone.conf";
      # Bounded retries so real faults surface as a failed unit.
      StartLimitBurst       = 5;
      StartLimitIntervalSec = 300;
    };

    serviceConfig = {
      Type = "notify";
      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount protondrive: /mnt/protondrive \
          --config=/persist/secrets/rclone.conf \
          --vfs-cache-mode=writes \
          --cache-dir=/var/cache/rclone \
          --dir-cache-time=72h \
          --allow-other
      '';
      Restart        = "on-failure";
      RestartSec     = 10;
      CacheDirectory = "rclone";
    };
  };

  systemd.tmpfiles.rules  = [ "d /mnt/protondrive 0755 root root -" ];
  programs.fuse.userAllowOther = true;

  # ── Packages ────────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    proton-vpn            # official GTK client
    proton-vpn-cli        # headless counterpart
    proton-pass           # native desktop client — packaged, no browser extension needed
    proton-authenticator  # Proton's TOTP app, same account
    rclone                # Drive backend, used by the unit above
  ];
}
