{ pkgs, ... }:

# ── Proton suite — VPN, Mail Bridge, Drive, Pass ──────────────────────────────
{
  # ── VPN ─────────────────────────────────────────────────────────────────────
  # No NixOS module exists; the proton-vpn app (package below) drives
  # NetworkManager over D-Bus, using networkmanager-openvpn / built-in WireGuard.

  # ── Mail Bridge ─────────────────────────────────────────────────────────────
  # User service (wantedBy graphical-session.target); stores credentials in the
  # Secret Service keyring, hence gnome-keyring.
  services.protonmail-bridge = {
    enable   = true;
    logLevel = "info";
    path     = [ pkgs.gnome-keyring ];  # keyring must be on the unit's PATH
  };

  # Unlocked by PAM `login`: there is no display manager.
  services.gnome.gnome-keyring.enable            = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # gcr-ssh-agent defaults on with gnome-keyring and conflicts with
  # programs.ssh.startAgent (system/network.nix); keep the OpenSSH agent.
  services.gnome.gcr-ssh-agent.enable = false;

  # ── Drive ───────────────────────────────────────────────────────────────────
  # No native client; rclone's protondrive backend. Type=notify so dependents
  # don't see an empty dir; no ExecStop since rclone unmounts on SIGTERM.
  # rclone.conf must stay writable: the backend rewrites session tokens into it.
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
