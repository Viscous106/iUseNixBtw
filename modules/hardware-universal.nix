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
    # Intel GPUs
    "i915"
    # AMD GPUs (modern + legacy)
    "amdgpu" "radeon"
    # NVIDIA open-source fallback
    "nouveau"
    # VirtIO GPU
    "virtio_gpu"
    # CPU frequency scaling
    "acpi_cpufreq" "cpufreq_ondemand" "cpufreq_performance"
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
  networking.wireless.iwd = {
    enable   = true;
    settings = {
      General.EnableNetworkConfiguration = false;  # let NetworkManager handle it
      P2P.Enable                         = false;  # disable Wi-Fi Direct — prevents the
                                                   # spurious NM "error setting IPv4 forwarding"
                                                   # warning on the iwd P2P virtual device at boot
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
