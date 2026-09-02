-- ~/.config/hypr/lua/startup_apps.lua
-- Migrated from configs/Startup_Apps.conf
-- exec-once -> hl.exec_cmd(...) inside the hyprland.start hook.
-- (Only the uncommented exec-once lines are carried over.)

local U = require("lua.user_defaults")
local scriptsDir = U.scriptsDir

hl.on("hyprland.start", function()
  hl.exec_cmd("keyd-application-mapper -d")

  -- wallpaper daemon / live-wallpaper restore (picks swww or mpvpaper from saved state)
  hl.exec_cmd(scriptsDir .. "/wallpaper-restore.sh")

  -- environment / session
  -- HYPRLAND_INSTANCE_SIGNATURE is what xdg-desktop-portal-hyprland uses to find
  -- the compositor socket when dbus activates it — without it in the activation
  -- environment the portal comes up unable to talk to Hyprland (screenshare and
  -- the file picker break). XDG_SESSION_TYPE is what portals/toolkits check to
  -- decide wayland vs x11. Both were previously missing on every session.
  -- (DISPLAY is deliberately left out: XWayland may not be up yet at exec-once
  -- time, and exporting an unset variable just errors.)
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE")
  hl.exec_cmd(scriptsDir .. "/KeybindsLayoutInit.sh")

  -- bar + dropdown terminal
  hl.exec_cmd("waybar")
  -- --prewarm: spawn it hidden in the scratchpad so the first SUPER+SHIFT+Return
  -- is instant. Without the flag it slides into view at login.
  hl.exec_cmd(scriptsDir .. "/Dropterminal.sh --prewarm kitty")

  -- polkit agent
  -- Polkit.sh hardcodes /usr/lib and /usr/libexec paths that don't exist on
  -- NixOS; Polkit-NixOS.sh (already in this repo) finds the real /nix/store
  -- path instead and is the one that actually works here.
  hl.exec_cmd(scriptsDir .. "/Polkit-NixOS.sh")

  -- tray / network / notifications / widgets
  hl.exec_cmd("nm-applet --indicator")
  hl.exec_cmd("nm-tray")
  hl.exec_cmd("swaync")
  hl.exec_cmd(scriptsDir .. "/StartAGS.sh")
  hl.exec_cmd("kdeconnect")
  hl.exec_cmd("blueman-applet")

  -- clipboard history
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")

  -- idle daemon (hyprlock) — hypridle keeps its own .conf
  hl.exec_cmd("hypridle -c " .. os.getenv("HOME") .. "/.config/hypr/configs/hypridle.conf")

  -- resume screen colour mode (monitor layout is handled automatically by lua/monitors.lua)
  hl.exec_cmd(scriptsDir .. "/ScreenMode.sh init")
end)
