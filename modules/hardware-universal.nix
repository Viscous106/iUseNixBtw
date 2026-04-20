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
  services.xserver.videoDrivers = [ "modesetting" "fbdev" ];
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
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";

  # TLP — good defaults for laptops; harmless on desktops
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC    = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT   = "schedutil";
      CPU_ENERGY_PERF_POLICY_ON_AC  = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      # Prevent USB autosuspend from killing the boot drive
      USB_AUTOSUSPEND               = 0;
      RUNTIME_PM_ON_AC              = "auto";
    };
  };

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
