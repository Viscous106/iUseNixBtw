-- ~/.config/hypr/lua/laptops.lua
-- Migrated from configs/Laptops.conf
-- NOTE: monitor setup lives in lua/monitors.lua (automatic, event-driven).

local U = require("lua.user_defaults")

-- touchpad toggle key
hl.bind("xf86TouchpadToggle", hl.dsp.exec_cmd(U.scriptsDir .. "/TouchPad.sh"))

-- per-device settings ($Touchpad_Device / $TOUCHPAD_ENABLED)
hl.device({
  name    = "asuf1204:00-2808:0202-touchpad",
  enabled = true,
})
