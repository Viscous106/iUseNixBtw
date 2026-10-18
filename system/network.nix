{ pkgs, lib, ... }:

{
  # ── NetworkManager + iwd ──────────────────────────────────────────────────
  networking.useDHCP               = lib.mkDefault true;
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  systemd.services.NetworkManager-wait-online.enable = false;  # kept ~6 s on the boot critical path
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

  # Power save off: 2.3x latency and ~7x jitter on this RTL8852BE.
  # If jitter returns: options rtw89_core disable_ps_mode=1.
  networking.networkmanager.wifi.powersave = false;

  # Regdomain IN: the default "00" makes 5 GHz scans passive, stalling roams.
  # Set here and in iwd; change both if abroad for long.
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=IN
  '';

  networking.wireless.iwd = {
    enable   = true;
    settings = {
      General.EnableNetworkConfiguration = false;  # NetworkManager does IP config
      General.Country                    = "IN";
      P2P.Enable                         = false;  # avoids a spurious NM IPv4-forwarding warning

      # Local 5 GHz APs sit at the default -76 dBm trigger, causing roam churn and rtw89 warning storms.
      General.RoamThreshold5G   = -80;
      General.RoamThreshold     = -74;   # 2.4 GHz, default -70
      General.RoamRetryInterval = 300;   # default 60 s
    };
  };

  # ── DNS ───────────────────────────────────────────────────────────────────
  # Local cache + Cloudflare (ts.net still via split DNS); DNSSEC/DoT off since both break captive portals.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS        = [ "1.1.1.1" "1.0.0.1" "9.9.9.9" ];
      DNSOverTLS = false;
      DNSSEC     = false;
      Cache      = true;
    };
  };
  networking.networkmanager.dns = "systemd-resolved";

  # ── Tailscale + SSH ───────────────────────────────────────────────────────
  services.tailscale.enable = true;  # run `sudo tailscale up` once to log in

  # sshd runs but is not opened on untrusted networks; reach it over Tailscale.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    openFirewall = false;
  };

  programs.ssh = {
    startAgent  = true;
    agentTimeout = "4h";
    extraConfig = ''
      Host *
        AddKeysToAgent     yes
        IdentityFile       /persist/secrets/ssh/id_ed25519
        ServerAliveInterval 60
    '';
  };

  # ── Firewall ──────────────────────────────────────────────────────────────
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.allowedTCPPorts   = [ 8443 ];  # claude-lend LAN listener

  networking.modemmanager.enable = false;  # no cellular modem
}
