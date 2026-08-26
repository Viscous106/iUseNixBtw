-- ~/.config/hypr/hyprland.lua
-- Entry point, migrated from hyprland.conf.
-- Hyprland loads this INSTEAD of hyprland.conf when it exists. Modules live in lua/.

local HOME = os.getenv("HOME")
-- make `require("lua.<module>")` resolve to ~/.config/hypr/lua/<module>.lua
package.path = HOME .. "/.config/hypr/?.lua;" .. package.path

require("lua.user_defaults")   -- shared vars + env (cached; loaded once)
require("lua.keybinds")
require("lua.startup_apps")
require("lua.laptops")
require("lua.window_rules")
require("lua.decorations")
require("lua.animations")
require("lua.system_settings")
require("lua.monitors")

-- extras that lived directly in hyprland.conf:
-- exec-once = $HOME/.config/hypr/initial-boot.sh  (kept for parity; script is optional)
hl.on("hyprland.start", function()
  hl.exec_cmd(HOME .. "/.config/hypr/initial-boot.sh")
end)
-- bind = SUPER SHIFT, C, exec, ~/.config/hypr/scripts/cursor_selector.sh
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/cursor_selector.sh"))
