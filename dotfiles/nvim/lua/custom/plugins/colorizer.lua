-- nvim-colorizer - show color previews
return {
  'NvChad/nvim-colorizer.lua',
  event = { 'BufReadPost', 'BufNewFile' },
  config = function()
    -- Color *names* (Red, Blue, ...) only in style files; in code they match
    -- identifiers like enum members. Hex codes and rgb()/hsl() stay everywhere.
    local with_names = { parsers = { names = { enable = true } } }
    require('colorizer').setup {
      filetypes = {
        '*',
        css = with_names,
        scss = with_names,
        sass = with_names,
        less = with_names,
        html = with_names,
      },
      user_default_options = {
        RGB = true, -- #RGB hex codes
        RRGGBB = true, -- #RRGGBB hex codes
        names = false, -- plugin default is true; re-enabled per filetype above
        RRGGBBAA = true, -- #RRGGBBAA hex codes
        rgb_fn = true, -- CSS rgb() and rgba() functions
        hsl_fn = true, -- CSS hsl() and hsla() functions
        css_fn = true, -- Enable all CSS *functions*
        mode = 'background', -- Set the display mode (foreground/background)
      },
    }
  end,
}
