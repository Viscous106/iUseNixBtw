{ config, pkgs, lib, ... }:

{
  # ── NVIDIA GPU (RTX 4050 Max-Q, Ada Lovelace) ────────────────────────────
  # This machine's internal display is wired through the NVIDIA GPU only —
  # dmesg shows it as the boot VGA device and the only real display-capable
  # card, and i915/amdgpu load but bind to nothing. Without this, the kernel
  # falls back to the generic "simple-framebuffer" driver (display only, zero
  # 3D), so Mesa has no GPU render node and Hyprland renders everything on
  # the CPU via llvmpipe — pegging every core (785%+ CPU observed) for
  # ordinary desktop compositing.
  #
  # This overrides hardware-universal.nix's portable mkDefault video driver
  # list — intentionally machine-specific, unlike that file.
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;   # required for correct Wayland/KMS behavior
    powerManagement.enable = true;
    # Ada Lovelace (RTX 40-series) has solid support in the open kernel
    # modules; nvidia recommends `open` for Turing and newer.
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # ── Disable runtime D3 (RTD3) on the dGPU ─────────────────────────────────
  # The open driver defaults to NVreg_DynamicPowerManagement=3, letting the GPU
  # runtime-suspend while the panel is off. With no iGPU that saves ~nothing,
  # and it deadlocks suspend: logind's VT switch holds console_lock →
  # fbcon_switch → nvidia-drm modeset → nvRmSetGc6Allowed → runtime-resume →
  # rm_transition_dynamic_power → console_lock again (self-deadlock,
  # "blocked on a semaphore likely last held by task systemd-logind"). Result:
  # black screen that never wakes; only a hard power-off recovers. Seen in the
  # journal 2026-10-12 (two hangs on suspend-then-hibernate).
  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x00
  '';
  # Keep the GPU's PCI runtime PM pinned "on" so supergfxd (Hybrid mode sets
  # it to "auto") can't re-enable runtime suspend behind the driver's back.
  services.udev.extraRules = ''
    ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
  '';
}
