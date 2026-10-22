{ config, pkgs, lib, ... }:

{
  # ── Kernel ────────────────────────────────────────────────────────────────
  # Latest kernel for widest new-hardware support; fall back to LTS if unstable.
  boot.kernelPackages = pkgs.linuxPackages_latest;

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

    # Kept on every host: harmless where absent, matches the CPU vendor if an iGPU appears.
    "amdgpu"
  ]
  # Speculative GPU drivers for unknown hardware, USB image only. The laptop has a
  # single NVIDIA GPU and no iGPU. Not mkForce: other modules append to this list.
  ++ lib.optionals (config.networking.hostName != "laptop") [
    "i915"        # Intel GPUs
    "radeon"      # AMD legacy
    "nouveau"     # NVIDIA open-source fallback
    "virtio_gpu"  # QEMU / VirtIO
  ];

  # Keep the legacy nvidiafb framebuffer off NVIDIA GPUs.
  boot.blacklistedKernelModules = [ "nvidiafb" ];

  # ── Firmware ──────────────────────────────────────────────────────────────
  # Full linux-firmware (~500 MB) for portability across unknown hardware.
  hardware.enableRedistributableFirmware = true;
  hardware.firmware = with pkgs; [ linux-firmware ];

  # ── Graphics — generic modesetting (works with every open-source driver) ─
  # mkDefault so hosts/nvidia.nix can override with a vendor driver.
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

  # ── Sound (PipeWire) ──────────────────────────────────────────────────────
  security.rtkit.enable = true;
  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;
    pulse.enable      = true;
    jack.enable       = true;
    # Low-latency defaults; raise quantum if audio crackles.
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
  # thermald is Intel-only; enable per machine if needed.
  services.thermald.enable = lib.mkDefault false;

  powerManagement.enable          = true;
  # amd-pstate-epp only offers performance/powersave; ppd drives EPP from powersave.
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # Lid close stays awake: resume from suspend leaves a black screen.
  services.logind.settings.Login = {
    HandleLidSwitch              = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked        = "ignore";
  };

  # Caelestia's bar needs UPower on DBus to show a battery instead of a
  # power-profile icon. Reports state only; independent of ppd.
  services.upower.enable = true;

  # ── Power profiles ────────────────────────────────────────────────────────
  # power-profiles-daemon, not TLP (they conflict): caelestia's profile switcher uses it over DBus.
  services.power-profiles-daemon.enable = true;

  # ── zram swap (hosts add a disk swapfile behind it) ───────────────────────
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
