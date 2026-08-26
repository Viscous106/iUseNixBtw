-- ~/.config/hypr/lua/user_defaults.lua
-- Migrated from configs/01-UserDefaults.conf
-- Shared user defaults. Returned as a table so other modules can `require` it
-- (require caches, so this runs exactly once even though several modules pull it in
--  — this replaces the old double-`source=` of 01-UserDefaults.conf).

local HOME = os.getenv("HOME")

-- env = EDITOR,nvim
hl.env("EDITOR", "nvim")

local M = {
  mainMod       = "SUPER",
  scriptsDir    = HOME .. "/.config/hypr/scripts",
  configsDir    = HOME .. "/.config/hypr/configs",
  term          = "kitty",                              -- $term
  files         = "thunar",                             -- $files
  edit          = os.getenv("EDITOR") or "nvim",        -- $edit = ${EDITOR:-nvim}
  Search_Engine = "https://www.google.com/search?q={}", -- $Search_Engine
}

return M
