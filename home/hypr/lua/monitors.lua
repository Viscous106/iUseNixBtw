-- ~/.config/hypr/lua/monitors.lua
-- Automatic, event-driven monitor management — no manual profile picker.
--
-- A baseline is set at config-parse time so the internal panel always has a
-- picture during boot. The real layout is decided by scripts/monitor-auto.sh,
-- which re-evaluates state and runs on:
--   * hyprland.start          (initial layout)
--   * monitor.added / removed (HDMI plugged / unplugged)
--   * Lid Switch on / off     (lid closed / opened)
-- See scripts/monitor-auto.sh for the full behavior table.

local HOME = os.getenv("HOME")
local auto = HOME .. "/.config/hypr/scripts/monitor-auto.sh"

-- Baseline: internal panel usable immediately; monitor-auto.sh refines on start.
-- Position it at -1920x0, matching INT_POS_DOCKED in monitor-auto.sh. The external
-- is always pinned at 0x0, so parking the panel to its left keeps the two regions
-- disjoint. A baseline of 0x0 collides with the external on every reload and makes
-- Hyprland latch the "Monitor eDP-1 overlaps with other monitor(s)" warning.
hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "-1920x0", scale = 1 })

-- Re-apply the automatic layout on startup and on any output hotplug.
hl.on("hyprland.start",  function() hl.exec_cmd(auto) end)
hl.on("monitor.added",   function() hl.exec_cmd(auto) end)
hl.on("monitor.removed", function() hl.exec_cmd(auto) end)

-- Lid closed / opened -> re-evaluate (external-only when docked, etc.).
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd(auto .. " closed"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(auto .. " open"), { locked = true })
