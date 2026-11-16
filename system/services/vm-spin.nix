{ pkgs, ... }:

# `vm-spin [/dev/sdX]`: boots the connected USB disk (a bare-metal Windows install) in QEMU/KVM, writes included.
let
  vm-spin = pkgs.writeShellApplication {
    name = "vm-spin";
    runtimeInputs = with pkgs; [ qemu_kvm swtpm util-linux coreutils gawk ];
    text = ''
      # The session's audio-shim LD_LIBRARY_PATH drags QEMU onto a libasound built for a newer glibc.
      unset LD_LIBRARY_PATH

      dev=''${1:-}
      if [ -z "$dev" ]; then
        mapfile -t found < <(lsblk -dnpo NAME,TRAN | awk '$2=="usb"{print $1}')
        [ "''${#found[@]}" -eq 1 ] || { echo "vm-spin: need exactly one USB disk, found ''${#found[@]}; pass /dev/sdX" >&2; exit 1; }
        dev=''${found[0]}
      fi
      [ -b "$dev" ] || { echo "vm-spin: $dev is not a block device" >&2; exit 1; }
      [ -w "$dev" ] || { echo "vm-spin: no write access to $dev (replug it so the udev rule applies)" >&2; exit 1; }
      if lsblk -nro MOUNTPOINTS "$dev" | grep -q .; then
        echo "vm-spin: $dev has mounted partitions; unmount them first" >&2; exit 1
      fi

      state=''${XDG_STATE_HOME:-$HOME/.local/state}/vm-spin
      run=''${XDG_RUNTIME_DIR:-/tmp}/vm-spin
      mkdir -p "$state/tpm" "$state/esp/EFI/BOOT" "$run"
      [ -e "$state/OVMF_VARS.fd" ] || install -m600 ${pkgs.OVMF.fd}/FV/OVMF_VARS.fd "$state/OVMF_VARS.fd"

      # OVMF has no boot entry for a foreign Windows ESP: fall back to a UEFI shell that chainloads it.
      install -m644 ${pkgs.edk2-uefi-shell}/shell.efi "$state/esp/EFI/BOOT/BOOTX64.EFI"
      cat > "$state/esp/startup.nsh" <<'NSH'
      @echo -off
      for %d in fs0 fs1 fs2 fs3 fs4 fs5
        if exist %d:\EFI\Microsoft\Boot\bootmgfw.efi then
          %d:\EFI\Microsoft\Boot\bootmgfw.efi
        endif
      endfor
      for %d in fs0 fs1 fs2 fs3 fs4 fs5
        if exist %d:\EFI\BOOT\BOOTX64.EFI then
          %d:\EFI\BOOT\BOOTX64.EFI
        endif
      endfor
      NSH

      swtpm socket --tpm2 --tpmstate dir="$state/tpm" --ctrl type=unixio,path="$run/tpm.sock" \
        --flags not-need-init,startup-clear &
      trap 'kill $! 2>/dev/null' EXIT

      # NVMe + xHCI + e1000e: drivers Windows already has from its bare-metal install.
      qemu-system-x86_64 \
        -machine q35,accel=kvm -cpu host,hv_relaxed,hv_vapic,hv_spinlocks=0x1fff,hv_time \
        -smp "''${VM_SPIN_CPUS:-4}" -m "''${VM_SPIN_MEM:-6G}" -rtc base=localtime \
        -drive if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.fd}/FV/OVMF_CODE.fd \
        -drive if=pflash,format=raw,file="$state/OVMF_VARS.fd" \
        -drive if=none,id=win,file="$dev",format=raw,cache=none,aio=native \
        -device nvme,drive=win,serial=vmspin,bootindex=0 \
        -device qemu-xhci \
        -drive file=fat:rw:"$state/esp",format=raw,if=none,id=esp \
        -device usb-storage,drive=esp,bootindex=1 \
        -chardev socket,id=tpm,path="$run/tpm.sock" -tpmdev emulator,id=tpm0,chardev=tpm \
        -device tpm-tis,tpmdev=tpm0 \
        -device usb-tablet -device usb-kbd \
        -device VGA,vgamem_mb=64 -display gtk \
        -audiodev pipewire,id=snd -device ich9-intel-hda -device hda-duplex,audiodev=snd \
        -nic user,model=e1000e
    '';
  };
in
{
  environment.systemPackages = [ vm-spin ];

  # Hands the logged-in user raw access to USB disks, so QEMU needs no root.
  services.udev.packages = [
    (pkgs.writeTextDir "etc/udev/rules.d/70-vm-spin.rules" ''
      SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_BUS}=="usb", TAG+="uaccess"
    '')
  ];
}
