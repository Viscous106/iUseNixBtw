-- Login autostart (hyprland.start hook).

local U = require("lua.user_defaults")
local scriptsDir = U.scriptsDir

hl.on("hyprland.start", function()
  hl.exec_cmd("keyd-application-mapper -d")

  -- Reapply the last wallpaper via the picker's own apply path (no Qt startup).
  hl.exec_cmd("wallpaper-picker --restore")

  -- Session env for dbus/systemd. The portal needs HYPRLAND_INSTANCE_SIGNATURE to
  -- find Hyprland; DISPLAY is left out since XWayland may not be up yet.
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")

  -- xdg-desktop-portal is Requisite=graphical-session.target, which nothing starts
  -- with systemd.enable = false; without it browser screen sharing fails. The fake
  -- target activates it. Must run after the env imports above.
  hl.exec_cmd("systemctl --user start nixos-fake-graphical-session.target")

  -- Caelestia shell: bar, notifications, launcher and OSDs in one process.
  hl.exec_cmd("caelestia-shell")
  -- With bar.persistent off the bar starts hidden; this shows it once IPC is up.
  hl.exec_cmd(scriptsDir .. "/CaelestiaBarInit.sh")
  -- --prewarm: start hidden so the first SUPER+SHIFT+Return is instant.
  hl.exec_cmd(scriptsDir .. "/DropTerminal.sh --prewarm kitty")

  -- polkit agent (NixOS variant resolves the agent from /nix/store)
  hl.exec_cmd(scriptsDir .. "/PolkitNixOS.sh")

  -- tray applets (idle/lock is caelestia's general.idle, home/desktop/caelestia.nix)
  hl.exec_cmd("nm-applet --indicator")
  hl.exec_cmd("kdeconnect")
  hl.exec_cmd("blueman-applet")

  -- clipboard history
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")

  -- convertible: `init` resets rotation/keyboard in case the last session died
  -- folded; the daemon self-locks, so reloads don't stack copies.
  hl.exec_cmd(scriptsDir .. "/AutoRotate.sh init")
  hl.exec_cmd(scriptsDir .. "/AutoRotate.sh daemon")

  -- resume screen colour mode
  hl.exec_cmd(scriptsDir .. "/ScreenMode.sh init")
end)
