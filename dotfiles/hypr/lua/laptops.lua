-- Laptop input devices and convertible (tablet mode) handling.

local U = require("lua.user_defaults")

-- touchpad toggle key
hl.bind("xf86TouchpadToggle", hl.dsp.exec_cmd(U.scriptsDir .. "/TouchPad.sh"))

-- Device name from `hyprctl devices`.
hl.device({
  name    = "elan-touchpad",
  enabled = true,
})

-- Map the touchscreen to the panel so touch follows rotation (otherwise taps
-- land 90° off on a rotated screen).
hl.device({
  name   = "elan-touchscreen",
  output = "eDP-1",
})

-- ── Convertible / tablet mode ─────────────────────────────────────────────
-- Folding: auto-rotate on, keyboard/touchpad muted; unfolding restores both
-- (scripts/auto-rotate.sh). locked = true so unfolding works on the lock screen.
local rotate = U.scriptsDir .. "/auto-rotate.sh"
hl.bind("switch:on:Tablet Mode Switch",  hl.dsp.exec_cmd(rotate .. " tablet on"),  { locked = true })
hl.bind("switch:off:Tablet Mode Switch", hl.dsp.exec_cmd(rotate .. " tablet off"), { locked = true })
