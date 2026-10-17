-- Autocompletion.
return {
  'saghen/blink.cmp',
  event = 'VimEnter',
  version = '1.*',
  dependencies = {
    -- Snippet Engine
    {
      'L3MON4D3/LuaSnip',
      version = '2.*',
      build = (function()
        -- jsregexp build for regex snippets; skipped without make.
        if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
          return
        end
        return 'make install_jsregexp'
      end)(),
      dependencies = {
      },
      opts = {},
    },
    'folke/lazydev.nvim',
  },
  --- @module 'blink.cmp'
  --- @type blink.cmp.Config
  opts = {
    keymap = {
      -- <CR> accepts when the menu is open, else newline; <S-CR> always inserts a newline.
      preset = 'enter',

      ['<S-CR>'] = { 'fallback' },
    },

    appearance = {
      nerd_font_variant = 'mono',
    },

    completion = {
      -- docs on <c-space>
      documentation = { auto_show = false, auto_show_delay_ms = 500 },
    },

    sources = {
      default = { 'lsp', 'path', 'snippets', 'lazydev' },
      providers = {
        lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
      },
    },

    snippets = { preset = 'luasnip' },

    -- Lua matcher: the Rust one downloads a prebuilt binary.
    fuzzy = { implementation = 'lua' },

    signature = { enabled = true },
  },
}
