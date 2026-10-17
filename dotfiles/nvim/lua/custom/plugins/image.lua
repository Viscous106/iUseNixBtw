-- image.nvim - Display images inline
return {
  '3rd/image.nvim',
  lazy = false,
  enabled = true,
  -- Skip image.nvim's luarocks build step: it only builds the optional
  -- `magick_rock` FFI processor, which needs a global Lua 5.1 + luarocks
  -- setup we don't have. We use the default `magick_cli` processor
  -- instead, which just shells out to `imagemagick`'s `magick` binary
  -- (already in PATH via home/viscous.nix's environment.systemPackages).
  -- Without this, every `:Lazy sync` prints a scary but harmless
  -- "Could not find Lua 5.1" build failure.
  build = false,
  config = function()
    require('image').setup {
      backend = 'kitty',
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { 'markdown', 'vimwiki', 'ipynb' },
        },
        neorg = {
          enabled = true,
          filetypes = { 'norg' },
        },
        typst = {
          enabled = true,
          filetypes = { 'typst' },
        },
        html = {
          enabled = false,
        },
        css = {
          enabled = false,
        },
      },
      -- no hard cell caps; let images scale to the window (aspect ratio is always preserved)
      max_width_window_percentage = 100,
      max_height_window_percentage = 100,
      window_overlap_clear_enabled = false,
      window_overlap_clear_ft_ignore = { 'cmp_menu', 'scrollview', 'scrollview_sign' },
      editor_only_render_when_focused = true,
      tmux_show_only_in_active_window = true,
      hijack_file_patterns = { '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.avif', '*.svg' },
    }
  end,
}
