-- Shared defaults, returned as a table for other modules to `require`.

local HOME = os.getenv("HOME")

hl.env("EDITOR", "nvim")

local M = {
  mainMod       = "SUPER",
  scriptsDir    = HOME .. "/.config/hypr/scripts",
  term          = "kitty",
  files         = "thunar",
  edit          = os.getenv("EDITOR") or "nvim",
  Search_Engine = "https://www.google.com/search?q={}",
}

return M
