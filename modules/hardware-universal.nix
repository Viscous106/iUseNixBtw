{ config, pkgs, lib, ... }:

{
  # ── Kernel ────────────────────────────────────────────────────────────────
  # linuxPackages_latest gives widest new-hardware support on a portable drive.
  # Switch back to linuxPackages (LTS) if you hit stability issues.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Broad hardware-compatibility kernel params
  boot.kernelParams = [
    "amd_iommu=on"          # AMD GPU / IOMMU correct init
    "intel_iommu=on"
    "iommu=pt"              # passthrough — avoids DMA issues
    "pcie_aspm=off"         # prevents link-power-state hangs on some laptops
    "nowatchdog"            # avoid NMI lockups on slow USB-boot
    "mitigations=auto"      # keep Spectre/Meltdown mitigations but don't kill perf
  ];

  # ── initrd — load EVERYTHING needed to mount root from USB ───────────────
  boot.initrd.availableKernelModules = [
    # USB host controllers (cover every generation)
    "xhci_pci" "xhci_hcd"
    "ehci_pci" "ehci_hcd"
    "ohci_pci" "ohci_hcd"
    "uhci_hcd"

    # USB storage
    "usb_storage" "uas"

    # SCSI / SATA / ATA / NVMe (for when the drive is in a dock or internal slot)
    "sd_mod" "sr_mod"
    "ahci" "ata_piix" "ata_generic"
    "nvme"

    # eMMC / SD card readers (some laptops use these internally)
    "mmc_block" "mmc_core" "sdhci" "sdhci_pci" "sdhci_acpi"

    # VirtIO (QEMU / cloud environments)
    "virtio_pci" "virtio_blk" "virtio_scsi"

    # VMware / VirtualBox
    "vmw_vmci" "vmxnet3" "vboxguest"

    # Filesystem
    "btrfs"

    # HID — keyboard/mouse available in initrd (useful for LUKS prompt etc.)
    "hid_generic" "usbhid" "i2c_hid" "i2c_hid_acpi"
  ];

  # GPU + other modules loaded after root is mounted (keeps initrd lean)
  boot.kernelModules = [
    # CPU frequency scaling
    "acpi_cpufreq" "cpufreq_ondemand" "cpufreq_performance"

    # AMD GPU — kept on every host. Harmless where absent, and it is the one
    # GPU driver matching this CPU vendor should a BIOS hybrid-graphics toggle
    # ever expose an iGPU.
    "amdgpu"
  ]
  # ── Speculative GPU drivers: portable USB image only ──────────────────────
  # These exist so the portable install boots on unknown hardware. On the
  # laptop they are dead weight: lspci reports exactly one display device
  # (NVIDIA AD107M — there is no iGPU at all), /sys/class/drm has a single card
  # bound to `nvidia`, and i915 / radeon / virtio_gpu all sit at used_by=0
  # having bound to nothing.
  #
  # nouveau is the one that is not merely wasteful: it is the open driver for
  # the very GPU the proprietary module drives. It stays out of the way today
  # only because the nvidia module blacklists it — an ordering guarantee worth
  # not relying on once the hardware is known.
  #
  # Deliberately not lib.mkForce: boot.kernelModules is a merged list and other
  # modules legitimately contribute to it (i2c-dev from apps-gaming; tun, veth,
  # bridge, br_netfilter, xt_nat from docker; uinput; nvidia_uvm). Forcing the
  # list would silently drop all of those.
  ++ lib.optionals (config.networking.hostName != "laptop") [
    "i915"        # Intel GPUs
    "radeon"      # AMD legacy
    "nouveau"     # NVIDIA open-source fallback
    "virtio_gpu"  # QEMU / VirtIO
  ];

  # Prevent nouveau from fighting NVIDIA proprietary drivers (harmless if no NVIDIA)
  boot.blacklistedKernelModules = [ "nvidiafb" ];

  # ── Firmware ──────────────────────────────────────────────────────────────
  # enableRedistributableFirmware = Intel NUC, AMD, WiFi chips, GPUs.
  # linux-firmware covers the rare cards not in redist (~500 MB, worth it for portability).
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = with pkgs; [ linux-firmware ];

  # ── Graphics — generic modesetting (works with every open-source driver) ─
  # mkDefault so a machine-specific module (see modules/hardware-nvidia.nix)
  # can override this with a real vendor driver without a "conflicting
  # definitions" error.
  services.xserver.videoDrivers = lib.mkDefault [ "modesetting" "fbdev" ];
  hardware.graphics = {
    enable      = true;
    enable32Bit = true;   # needed for Steam / Wine / 32-bit Vulkan
    extraPackages = with pkgs; [
      # Intel VA-API (hardware video decode/encode)
      intel-media-driver        # iHD   (Gen 8+, Broadwell+)
      intel-vaapi-driver        # i965  (older Gen, Haswell and below)
      # AMD OpenCL (Vulkan/RADV is in Mesa by default — no extra package needed)
      rocmPackages.clr.icd
      # VA-API / VDPAU inspection tools
      libva-utils
      vdpauinfo
    ];
  };

  # ── Input — Libinput covers touchpads, mice, tablets on all laptops ───────
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling   = true;
      tapping            = true;
      disableWhileTyping = true;
    };
  };

  # ── Network ───────────────────────────────────────────────────────────────
  networking.useDHCP               = lib.mkDefault true;
  networking.networkmanager.enable = true;

  # iwd gives better WiFi support on tricky chipsets (Intel AX series etc.)
  networking.networkmanager.wifi.backend = "iwd";

  # ── WiFi power save — off ─────────────────────────────────────────────────
  # NetworkManager leaves `wifi.powersave` unset by default, which means "don't
  # touch it", which means the mac80211/rtw89 default (on) wins. On this card
  # (RTL8852BE, rtw89_8852be) that is expensive: measured against the LAN
  # gateway at -43 dBm, 60 ICMP echoes at 0.2 s, nothing else on the link —
  #
  #   power_save on    avg 3.76 ms   max 71.9 ms   mdev 10.62 ms
  #   power_save off   avg 1.62 ms   max 10.8 ms   mdev  1.54 ms
  #
  # 2.3x the average, 6.6x the worst case and 6.9x the jitter, on the hop to a
  # router three metres away. Throughput is unaffected either way (~190-250
  # Mbit/s to Cloudflare in both states) — this is purely a latency and jitter
  # tax, which is exactly the part a human notices: it is paid per round trip,
  # so it lands on interactive traffic (SSH keystrokes, page loads that fan out
  # into many small requests, calls) and not on bulk downloads.
  #
  # The mechanism is PS-Poll: with power save on, the radio sleeps between
  # beacons and only wakes on the DTIM interval, so an inbound packet arriving
  # mid-sleep waits for the next wake-up. `dtim period: 1` and `beacon int: 100`
  # on this AP means a worst case around one beacon interval, which matches the
  # ~70-100 ms outliers above.
  #
  # false -> NM writes `wifi.powersave=2` (disable) as the connection default.
  # If the jitter ever comes back with this set, the next layer down is rtw89's
  # own low-power mode, which NM does not reach:
  #   boot.extraModprobeConfig = "options rtw89_core disable_ps_mode=1";
  # and below that the PCIe L1 substates (`rtw89_pci.disable_aspm_l1ss=1`).
  # Neither was needed here — both were left alone and the numbers above are
  # with the stock values (disable_ps_mode=N, ASPM L1.2 enabled by firmware).
  #
  # Cost: a few hundred mW of extra idle draw on battery. That is the trade.
  networking.networkmanager.wifi.powersave = false;

  # ── Regulatory domain ─────────────────────────────────────────────────────
  # The kernel boots with `cfg80211.ieee80211_regdom=00` — the "world" domain —
  # and nothing here ever moved it off that, even though wireless-regdb is
  # installed and the certificates load fine ("Loading compiled-in X.509
  # certificates for regulatory database"). World is the deliberately pessimal
  # fallback, and `iw reg get` shows what it costs:
  #
  #   country 00   every 5 GHz band flagged PASSIVE-SCAN, all limits (6, 20)
  #   country IN   no PASSIVE-SCAN, 30 dBm on UNII-1/UNII-3, 6 GHz unlocked
  #
  # PASSIVE-SCAN is the expensive flag. It forbids sending probe requests on
  # those channels, so the card cannot ask "who is there" — it has to park on
  # each channel and wait for a beacon. A full scan measured 5.06 s under 00
  # versus 4.14 s under IN, and the card is off its operating channel for that
  # whole time, so every scan is a traffic stall. That matters here because iwd
  # roam-scans on a timer (6 scans in the last 20 minutes, at -41 dBm) — see
  # the roam-churn note below, which tuned the thresholds but could not make
  # the scans themselves cheaper.
  #
  # It also explains iwd's "Failed to find band with country string 'IN 32' and
  # oper class 4" — the AP advertises IN in its country IE, iwd tries to honour
  # it, and the world domain has no matching band to map it onto.
  #
  # Set in two places on purpose: the modprobe option is the boot-time default
  # for cfg80211 itself, and iwd's Country re-asserts it as a user hint once
  # the wireless stack is up.
  #
  # NOTE: this is a fixed hint, and this is a laptop. IN is correct where it
  # lives (time.timeZone = "Asia/Kolkata"). If you take it abroad for more than
  # a few days, change both values or you will be transmitting under the wrong
  # limits — legally, and on channels the local APs may not use.
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=IN
  '';
  networking.wireless.iwd = {
    enable   = true;
    settings = {
      General.EnableNetworkConfiguration = false;  # let NetworkManager handle it

      # Regulatory domain, the wireless-stack half of the boot.extraModprobeConfig
      # setting above. Without it iwd logs "Failed to find band with country
      # string 'IN 32' and oper class 4" on every association, because it is
      # trying to honour the AP's country IE against a world-domain band list.
      General.Country                    = "IN";
      P2P.Enable                         = false;  # disable Wi-Fi Direct — prevents the
                                                   # spurious NM "error setting IPv4 forwarding"
                                                   # warning on the iwd P2P virtual device at boot

      # ── Roam churn ────────────────────────────────────────────────────────
      # RoamThreshold5G defaults to -76 dBm. On the APs this machine actually
      # sees ("Create Impact", two BSSes on 5 GHz) the signal sits at -68 to
      # -76 — i.e. permanently at the trigger — so iwd roam-scanned every
      # RoamRetryInterval (60 s) and ping-ponged between e8:10:98:6e:84:70 and
      # e8:10:98:6f:06:30 all day. Each scan interrupts traffic, and each roam
      # re-negotiates rates.
      #
      # This matters beyond the churn itself: the rtw89 RX-stats warning storm
      # (46k kernel WARNs in one session, ~3 GB of journal) began 26 s after the
      # first roam of the boot and only ever occurred inside roam-heavy windows
      # — never during a steady link, including under a verified 52 MiB
      # download. The WARN itself is an upstream driver bug (it cannot map HE
      # rate index 111; valid ranges are 0-60 and 61-68) and is not fixable
      # from configuration — but not thrashing the association avoids the
      # condition that provokes it.
      #
      # -80 still leaves CriticalRoamThreshold5G (-82, unchanged) below it, so a
      # genuinely dying link still roams. Raise this back toward -76 if you move
      # between APs often and notice it clinging to a weak one.
      General.RoamThreshold5G  = -80;
      General.RoamThreshold    = -74;   # 2.4 GHz, default -70
      General.RoamRetryInterval = 300;  # default 60 s
    };
  };

  # ── Sound (PipeWire) ──────────────────────────────────────────────────────
  security.rtkit.enable = true;
  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
    jack.enable       = true;
    # Comfortable low-latency defaults — tweak if you get audio crackle
    extraConfig.pipewire."92-low-latency" = {
      context.properties = {
        default.clock.rate        = 48000;
        default.clock.quantum     = 512;
        default.clock.min-quantum = 32;
        default.clock.max-quantum = 8192;
      };
    };
  };

  # ── Power & Thermals ──────────────────────────────────────────────────────
  # thermald is Intel-only — disabled by default so this config is safe on AMD.
  # Override with: services.thermald.enable = true; in a per-machine module.
  services.thermald.enable = lib.mkDefault false;

  powerManagement.enable          = true;
  # amd-pstate-epp offers only `performance` and `powersave` --- schedutil is
  # not in scaling_available_governors on this CPU, so the value that used to
  # be here failed silently. powersave is the one power-profiles-daemon drives
  # through EPP; it raises the governor to performance itself when the
  # performance profile is selected.
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # UPower — the DBus battery/AC service. NixOS leaves it off by default, and
  # nothing else here pulled it in, so org.freedesktop.UPower was simply absent
  # from the bus. Anything asking the bus for battery state got nothing: the
  # kernel still exports /sys/class/power_supply/BAT1, but that is not where
  # desktop clients look.
  #
  # Caelestia's bar reads Quickshell.Services.UPower. With no daemon,
  # UPower.displayDevice.isLaptopBattery is false, and its BatteryStatus
  # component treats that as "desktop machine" and falls back to drawing the
  # power-profile icon (a balance scale) instead of a battery. Turning this on
  # is what makes the battery entry show a real charge level.
  # Independent of TLP — TLP sets policy, UPower only reports state.
  services.upower.enable = true;

  # ── Power profiles — power-profiles-daemon, NOT TLP ────────────────────
  # The two cannot coexist: nixpkgs' power-profiles-daemon module asserts
  # `!config.services.tlp.enable`. TLP was here first, and that is exactly why
  # the quiet/balanced/performance switcher in caelestia's battery popout
  # rendered fine but did nothing — it drives PowerProfiles over DBus, and with
  # no ppd on the bus every click was a silent no-op.
  #
  # This hardware is the good case for ppd: amd-pstate-epp (Ryzen 7 7435HS)
  # plus a working ACPI platform_profile advertising `quiet balanced
  # performance` — precisely the three-way control ppd exposes.
  #
  # Where each setting from the old TLP block went:
  #   CPU_SCALING_GOVERNOR_ON_{AC,BAT}    ppd, and switchable at runtime
  #   CPU_ENERGY_PERF_POLICY_ON_{AC,BAT}  ppd, through EPP
  #   USB_AUTOSUSPEND = 0                 already covered by the udev rule
  #                                       further down, which is what actually
  #                                       guards the USB boot drive
  #   RUNTIME_PM_ON_AC = "auto"           dropped; only ever applied on AC
  #
  # The real cost is TLP's OTHER defaults, which were never set explicitly here
  # (disk APM, wifi power save). On-battery draw may shift slightly.
  services.power-profiles-daemon.enable = true;

  # ── zram swap (no swapfile on compressed BTRFS) ───────────────────────────
  zramSwap.enable        = true;
  zramSwap.algorithm     = "zstd";
  zramSwap.memoryPercent = 50;

  # ── udev — extra rules for portability ────────────────────────────────────
  services.udev.extraRules = ''
    # Give all users write access to backlight control (brightness keys)
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod a+w /sys/class/backlight/%k/brightness"

    # Disable USB autosuspend globally (prevents boot drive from being suspended)
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend_delay_ms", ATTR{power/autosuspend_delay_ms}="-1"
  '';

  # ── Fwupd — firmware updates for any supported device ─────────────────────
  services.fwupd.enable = true;
}
