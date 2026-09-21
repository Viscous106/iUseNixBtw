{ pkgs, ... }:

# ── Proton suite — VPN, Mail Bridge, Drive, Pass ──────────────────────────────
# Rewrite of a draft that would not have evaluated. Every attribute below was
# verified against the pinned nixpkgs source (flake.lock rev 5545adf, 26.11)
# before being added — same rule as apps-system.nix, nothing here is guessed.
#
# What the draft got wrong, and why each fix is what it is:
#
#   1. `services.protonvpn` does not exist. Grepping the whole of
#      nixos/modules for "proton" returns exactly one hit —
#      services/mail/protonmail-bridge.nix. There is no VPN module in
#      nixpkgs, and flake.lock has no third-party protonvpn input either, so
#      the draft's `services.protonvpn = { ... }` was an eval error, not a
#      missing import. Handled as a package + NetworkManager below.
#
#   2. `environment.systemPackages` was assigned TWICE in the same attribute
#      set. That is a hard eval error in Nix ("attribute already defined"),
#      not a merge — the two lists are collapsed into one below.
#
#   3. `services.protonmail-bridge.nonInteractive` is not an option. The
#      module takes only enable/package/path/logLevel, and it already passes
#      --noninteractive unconditionally, so the flag was both invalid and
#      redundant.
#
#   4. `protonvpn-gui` still resolves but is a deprecation alias
#      (aliases.nix:2085, "renamed to/replaced by 'proton-vpn'", added
#      2026-02-23) and prints a warning on every rebuild. Use `proton-vpn`.

{
  # ── VPN ─────────────────────────────────────────────────────────────────────
  # The official GTK app (proton-vpn 4.16.5) drives NetworkManager over D-Bus
  # rather than managing its own tunnels, so there is no daemon to enable and
  # no credentials file to place — you log in once in the GUI. NM is already
  # on (configuration.nix:7) and networkmanager-openvpn is already registered
  # as a plugin (apps-system.nix:130), which is what the app needs for its
  # OpenVPN protocol option; WireGuard is handled by NM's built-in support.
  #
  # There is deliberately no equivalent of the draft's `endpoint = "US-FREE#1"`:
  # server choice lives in the app's own config, not in the system closure.

  # ── Mail Bridge ─────────────────────────────────────────────────────────────
  # NOTE this module defines a systemd *user* service, wantedBy
  # graphical-session.target — it is not a system daemon, and it will not
  # start on a bare TTY before a graphical session exists.
  #
  # The bridge keeps its Proton credentials in a keyring via go-keyring, and
  # this config had no Secret Service provider at all (no gnome-keyring, no
  # kwallet, no pass), which is what would actually have broken the draft's
  # "automatically logs in if your system keyring is configured" assumption.
  # gnome-keyring is enabled below to close that gap.
  services.protonmail-bridge = {
    enable   = true;
    logLevel = "info";
    path     = [ pkgs.gnome-keyring ];  # keyring must be on the unit's PATH
  };

  # Secret Service provider for the bridge (and anything else using libsecret).
  # Unlocked by PAM at login: there is no display manager in this config, so
  # the relevant PAM service is `login` (TTY), not greetd/sddm.
  services.gnome.gnome-keyring.enable            = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # gnome-keyring also ships an SSH agent, and
  # `services.gnome.gcr-ssh-agent.enable` DEFAULTS to
  # `config.services.gnome.gnome-keyring.enable` (gcr-ssh-agent.nix:22) — so
  # switching the keyring on silently switches on a second agent and trips its
  # assertion against `programs.ssh.startAgent`, which this config already sets
  # (configuration.nix:138). Caught by evaluating the full host, not just this
  # module. Keeping the existing OpenSSH agent (it has agentTimeout = "4h" and
  # a configured identity at /persist/secrets/ssh) and declining gcr's.
  services.gnome.gcr-ssh-agent.enable = false;

  # ── Drive ───────────────────────────────────────────────────────────────────
  # No native Linux client is packaged, so rclone's protondrive backend does
  # the work (confirmed present: `rclone help backends` lists "protondrive",
  # rclone 1.75.0).
  #
  # Fixes over the draft's unit:
  #   - `wants` added. `after = [ "network-online.target" ]` alone only orders
  #     against that target; it never pulls it into the transaction, so the
  #     unit could start before the network was up.
  #   - Type = "notify" instead of "simple" — rclone's own mount docs: "When
  #     running rclone mount as a systemd service, it is possible to use
  #     Type=notify. In this case the service will enter the started state
  #     after the mountpoint has been successfully set up." With "simple",
  #     dependent units see an empty directory.
  #   - Mountpoint created via tmpfiles; systemd will not mkdir it for you and
  #     the unit fails outright if /mnt/protondrive does not exist.
  #   - --allow-other so your user can read a root-owned FUSE mount, which
  #     needs user_allow_other in /etc/fuse.conf — that is what
  #     programs.fuse.userAllowOther writes.
  #   - No ExecStop. rclone unmounts itself on SIGTERM; a `fusermount3 -u`
  #     ExecStop fails (and marks the unit failed) whenever rclone got there
  #     first.
  #   - Secrets path moved to /persist/secrets, matching this repo's existing
  #     convention (configuration.nix:143 uses /persist/secrets/ssh). Note the
  #     file must stay WRITABLE: the protondrive backend rewrites cached
  #     session tokens back into rclone.conf, so a read-only store path or a
  #     root-only /var/lib path chosen by hand will break re-auth.
  systemd.services.protondrive-mount = {
    description = "Proton Drive (rclone FUSE mount)";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    wantedBy    = [ "multi-user.target" ];

    # The remote is created interactively by `rclone config`, so on a fresh
    # machine this unit has nothing to mount yet. Without a condition it exits
    # 1 ("didn't find section in config file"), restart-loops on RestartSec,
    # and makes `nixos-rebuild switch` itself return non-zero. A failed
    # ConditionPathExists is not a failure: systemd skips the unit and records
    # "condition failed", the rebuild stays green, and it starts normally once
    # the config file is there.
    unitConfig = {
      ConditionPathExists = "/persist/secrets/rclone.conf";
      # Bounded retries. A real fault (expired session, Proton outage) should
      # surface as a failed unit you can see, not an indefinite 10s loop
      # filling the journal. These two live in [Unit], not [Service] — they
      # were moved out of [Service] in systemd 229 and only linger there as
      # deprecated compat.
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
  # Single definition — see note 2 above.
  environment.systemPackages = with pkgs; [
    proton-vpn            # official GTK client (was: protonvpn-gui, deprecated alias)
    proton-vpn-cli        # headless counterpart; protonvpn-cli is a throw alias now
    proton-pass           # native desktop client — packaged, no browser extension needed
    proton-authenticator  # Proton's TOTP app, same account
    rclone                # Drive backend, used by the unit above
    # bitwarden-desktop intentionally dropped: the draft added it as an
    # "alternative" alongside proton-pass, which is two password managers on
    # one system. Add it back deliberately if you actually keep vaults in both.
  ];
}
