-- ~/.config/hypr/lua/laptops.lua
-- Migrated from configs/Laptops.conf
-- NOTE: monitor setup lives in lua/monitors.lua (automatic, event-driven).

local U = require("lua.user_defaults")

-- touchpad toggle key
hl.bind("xf86TouchpadToggle", hl.dsp.exec_cmd(U.scriptsDir .. "/TouchPad.sh"))

-- per-device settings ($Touchpad_Device / $TOUCHPAD_ENABLED)
-- Was "asuf1204:00-2808:0202-touchpad", carried over from the old Asus laptop —
-- no such device exists on this machine, so the rule was silently inert.
-- `hyprctl devices` reports the real one as elan-touchpad.
hl.device({
  name    = "elan-touchpad",
  enabled = true,
})

-- Bind the touchscreen to the internal panel. This is what makes touch input
-- follow the display's transform: without an output mapping the compositor
-- keeps feeding it raw panel coordinates, so a rotated screen ends up with
-- taps landing 90° away from your finger.
hl.device({
  name   = "elan-touchscreen",
  output = "eDP-1",
})

-- ── Convertible / tablet mode ─────────────────────────────────────────────
-- Folding the lid past ~180° makes the EC assert SW_TABLET_MODE, which Hyprland
-- surfaces as the "Tablet Mode Switch" device. Folding starts obeying the
-- accelerometer and mutes the keyboard/touchpad; unfolding restores both.
-- See scripts/auto-rotate.sh for the behaviour.
--
-- locked = true so unfolding still restores the keyboard while hyprlock is up —
-- otherwise a session locked in tablet mode would have no way to accept a
-- password. Same reasoning as the Lid Switch binds in lua/monitors.lua.
local rotate = U.scriptsDir .. "/auto-rotate.sh"
hl.bind("switch:on:Tablet Mode Switch",  hl.dsp.exec_cmd(rotate .. " tablet on"),  { locked = true })
hl.bind("switch:off:Tablet Mode Switch", hl.dsp.exec_cmd(rotate .. " tablet off"), { locked = true })
