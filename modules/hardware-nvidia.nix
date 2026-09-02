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
}
