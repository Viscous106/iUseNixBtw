-- Hyprland entry point (loaded instead of hyprland.conf). Modules live in lua/.

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

-- nwg-displays' generated layout: ~/.config/hypr/monitors.lua (via package.path).
require("monitors")

