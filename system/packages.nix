{ pkgs, ... }:

{
  # System-wide CLI tools (available to root and in the TTY too).
  environment.systemPackages = with pkgs; [
    # Basics
    git curl wget vim
    btrfs-progs gptfdisk parted
    pciutils usbutils lshw
    htop btop
    eza

    # Hardware / power / diagnostics
    acpi
    alsa-utils
    inxi
    hwinfo
    powertop
    smartmontools
    ddcutil         # DDC/CI monitor control over the display cable

    # Filesystems
    dosfstools
    ntfs3g
    exfatprogs
    udiskie
    unionfs-fuse

    # Networking / diagnostics
    iptables        # CLI only; the active firewall is networking.firewall
    dnsmasq
    nmap
    mtr
    net-tools
    netcat-openbsd
    iw
    wirelesstools
    wpa_supplicant  # wpa_cli for manual debugging
    wireguard-tools

    # Security / pentesting
    bettercap
    thc-hydra       # the login cracker (pkgs.hydra is the Nix CI server)
    proxychains-ng
    torsocks

    # Calendar / CalDAV
    gcalcli
    khal
    vdirsyncer

    # Toys
    asciiquarium
    cmatrix
    sl

    malcontent      # parental controls CLI
  ];
}
