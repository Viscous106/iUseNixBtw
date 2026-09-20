-- ~/.config/hypr/lua/monitors.lua
-- Event hooks and lid binds for monitor management. Owns no geometry itself:
-- layout is decided by scripts/monitor-auto.sh (profile selection) and carried
-- by nwg-displays' generated ~/.config/hypr/monitors.lua, which hyprland.lua
-- requires after this module. This file only wires monitor-auto.sh to run on:
--   * hyprland.start          (initial layout)
--   * monitor.added / removed (HDMI plugged / unplugged)
--   * Lid Switch on / off     (lid closed / opened)
-- A manual override also exists via scripts/monitor-pick.sh (SUPER+ALT+SHIFT+M),
-- but it is not sticky: the next event above recomputes and can override it.
-- See scripts/monitor-auto.sh for the full behavior table.

local HOME = os.getenv("HOME")
local auto = HOME .. "/.config/hypr/scripts/monitor-auto.sh"

-- No baseline hl.monitor() here. Geometry is owned by ~/.config/hypr/monitors.lua,
-- which nwg-displays regenerates on every Apply and hyprland.lua requires after
-- this module. A baseline would run at config-parse time on every reload and
-- overwrite the profile's position for eDP-1.

-- Re-apply the automatic layout on startup and on any output hotplug.
hl.on("hyprland.start",  function() hl.exec_cmd(auto) end)
hl.on("monitor.added",   function() hl.exec_cmd(auto) end)
hl.on("monitor.removed", function() hl.exec_cmd(auto) end)

-- Lid closed / opened -> re-evaluate (external-only when docked, etc.).
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd(auto .. " closed"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(auto .. " open"), { locked = true })
