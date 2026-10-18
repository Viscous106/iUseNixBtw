{ config, pkgs, lib, ... }:

{
  # ── NVIDIA GPU (RTX 4050 Max-Q, Ada Lovelace) ────────────────────────────
  # The internal display is wired only to the dGPU; without the driver Hyprland falls back to llvmpipe.
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;   # required for correct Wayland/KMS behavior
    powerManagement.enable = true;
    # NVIDIA recommends the open kernel modules for Turing and newer.
    open = true;
    nvidiaSettings = true;
    # Patched to debounce AC _PSR events: a flapping charger raced nvidia-drm init and hung boot.
    # Drop once the charger is fixed or the patch stops applying.
    package =
      let base = config.boot.kernelPackages.nvidiaPackages.stable;
      in base // {
        open = base.open.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ../pkgs/nvidia-open-psr-debounce.patch ];
        });
      };
  };

  # ── Disable runtime D3 (RTD3) on the dGPU ─────────────────────────────────
  # Saves ~nothing without an iGPU and self-deadlocks on console_lock during suspend.
  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x00
  '';
  # Keep the GPU's PCI runtime PM pinned "on" so supergfxd (Hybrid mode sets
  # it to "auto") can't re-enable runtime suspend behind the driver's back.
  services.udev.extraRules = ''
    ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
  '';
}
