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
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd(scriptsDir .. "/KeybindsLayoutInit.sh")

  -- bar + dropdown terminal
  hl.exec_cmd("waybar")
  -- --prewarm: spawn it hidden in the scratchpad so the first SUPER+SHIFT+Return
  -- is instant. Without the flag it slides into view at login.
  hl.exec_cmd(scriptsDir .. "/Dropterminal.sh --prewarm kitty")

  -- polkit agent
  hl.exec_cmd(scriptsDir .. "/Polkit.sh")

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
