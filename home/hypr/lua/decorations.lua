-- ~/.config/hypr/lua/decorations.lua
-- Migrated from configs/decorations.conf
-- col.active_border etc. -> general.col.active_border ; colors are plain strings.

hl.config({
  general = {
    border_size = 2,
    gaps_in     = 2,
    gaps_out    = 4,
    col = {
      active_border   = "rgba(595959ff)",
      inactive_border = "rgba(333333ff)",
    },
  },

  decoration = {
    rounding           = 10,
    active_opacity     = 1.0,
    inactive_opacity   = 0.9,
    fullscreen_opacity = 1.0,
    dim_inactive       = true,
    dim_strength       = 0.1,
    dim_special        = 0.8,
    shadow = {
      enabled        = true,
      range          = 3,
      render_power   = 1,
      color          = "rgba(595959ff)",
      color_inactive = "rgba(333333ff)",
    },
    blur = {
      enabled           = true,
      size              = 6,
      passes            = 2,
      ignore_opacity    = true,
      new_optimizations = true,
      special           = true,
      popups            = true,
    },
  },

  group = {
    col = { border_active = "rgba(eeeeeeff)" },
    groupbar = {
      col = { active = "rgba(1a1a1aff)" },
    },
  },
})
