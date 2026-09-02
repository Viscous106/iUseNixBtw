{ ... }:

# ── scaler-listen — a personal project (github-less, local repo) ported
# verbatim from Arch's ~/.config/systemd/user/scaler-*.{service,timer}.
# Working copy vendored at home/scaler-content (out-of-store symlink below,
# same pattern as tmux/rofi/tmuxifier); secrets copied to
# /persist/secrets/scaler-listen-env following this repo's existing
# secrets convention (git-identity, claude_api) rather than committing them.
#
# scaler-reddit-poll is defined but has NO `Install.wantedBy` below — Arch
# never enabled its timer either (its own unit header says "PHASE 2. Enable
# alongside scaler-reddit-poll.service."), so this preserves that
# deliberately-inactive state.
{
  systemd.user.services = {
    scaler-daily = {
      Unit = {
        Description = "Scaler listening — daily search, settle, classify and IG insights";
        After  = [ "network-online.target" ];
        Wants  = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        WorkingDirectory  = "%h/Viscous/scaler-content";
        EnvironmentFile   = "/persist/secrets/scaler-listen-env";
        # Order matters: search finds new submissions; settle finalises
        # scores that have stopped moving; classify labels whatever is now
        # present; ig pulls Instagram insights; retain purges bodies past
        # their TTL. Running classify before settle would label items whose
        # metrics are still in flux.
        ExecStart = [
          "/usr/bin/env uv run scaler-listen search"
          "/usr/bin/env uv run scaler-listen settle"
          "/usr/bin/env uv run scaler-listen classify"
          "/usr/bin/env uv run scaler-listen ig"
          "/usr/bin/env uv run scaler-listen retain"
        ];
        SuccessExitStatus = "0 2";
        Restart    = "on-failure";
        RestartSec = "30min";
      };
    };

    scaler-digest = {
      Unit = {
        Description = "Scaler listening — build and publish the weekly digest";
        After  = [ "network-online.target" ];
        Wants  = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        WorkingDirectory = "%h/Viscous/scaler-content";
        EnvironmentFile  = "/persist/secrets/scaler-listen-env";
        ExecStart  = "/usr/bin/env uv run scaler-listen digest";
        Restart    = "on-failure";
        RestartSec = "15min";
      };
    };

    scaler-export = {
      Unit = {
        Description = "Scaler listening — refresh the analysis spreadsheet";
        After  = [ "network-online.target" ];
        Wants  = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        WorkingDirectory = "%h/Viscous/scaler-content";
        EnvironmentFile  = "/persist/secrets/scaler-listen-env";
        # Deliberately no --include-bodies: the export overwrites each tab in
        # place, so a failed run leaves the previous export intact.
        ExecStart = [
          "/usr/bin/env uv run scaler-listen classify"
          "/usr/bin/env uv run scaler-listen export --to sheets"
        ];
        Restart    = "on-failure";
        RestartSec = "30min";
      };
    };

    scaler-reddit-poll = {
      Unit = {
        Description = "Scaler listening — poll Reddit comment streams";
        After  = [ "network-online.target" ];
        Wants  = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        WorkingDirectory = "%h/Viscous/scaler-content";
        EnvironmentFile  = "/persist/secrets/scaler-listen-env";
        ExecStart  = "/usr/bin/env uv run scaler-listen poll";
        Restart    = "on-failure";
        RestartSec = "2min";
      };
    };
  };

  systemd.user.timers = {
    scaler-daily = {
      Unit.Description = "Daily Scaler listening maintenance";
      Timer = {
        OnCalendar        = "*-*-* 03:30:00 Asia/Kolkata";
        Persistent         = true;
        RandomizedDelaySec = "15min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    scaler-digest = {
      Unit.Description = "Weekly Scaler listening digest (Monday morning)";
      Timer = {
        OnCalendar         = "Mon *-*-* 09:00:00 Asia/Kolkata";
        Persistent          = true;
        RandomizedDelaySec  = "5min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    scaler-export = {
      Unit.Description = "Refresh the analysis spreadsheet every 3 hours";
      Timer = {
        OnCalendar         = "*-*-* 00/3:15:00 Asia/Kolkata";
        Persistent          = true;
        OnBootSec           = "5min";
        RandomizedDelaySec  = "5min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # No Install.WantedBy — matches Arch, where this timer exists but was
    # never linked into timers.target.wants/ ("PHASE 2").
    scaler-reddit-poll = {
      Unit.Description = "Poll Reddit comment streams every 5 minutes";
      Timer = {
        OnCalendar  = "*:0/5";
        Persistent  = true;
        OnBootSec   = "2min";
      };
    };
  };
}
