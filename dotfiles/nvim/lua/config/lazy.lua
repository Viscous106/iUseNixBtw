-- [[ lazy.nvim bootstrap ]]
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Plugins ]]
require('lazy').setup({
  'NMAC427/guess-indent.nvim', -- Detect tabstop and shiftwidth automatically

  { -- git signs in the gutter
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },

  require 'config.plugins.which-key',
  require 'config.plugins.telescope',

  -- LSP Plugins
  {
    -- Lua LSP types for the Neovim API
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  require 'config.plugins.lspconfig',

  require 'config.plugins.conform',

  require 'config.plugins.blink',

  { -- colorscheme
    'folke/tokyonight.nvim',
    priority = 1000, -- load before other start plugins
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false },
        },
      }

      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- around/inside textobjects (va), yinq, ci')
      require('mini.ai').setup { n_lines = 500 }

      -- surroundings: saiw), sd', sr)'
      require('mini.surround').setup()
    end,
  },
  require 'config.plugins.treesitter',

  -- Markdown plugins
  { 'preservim/vim-markdown', ft = 'markdown' },
  {
    'iamcco/markdown-preview.nvim',
    ft = 'markdown',
    build = 'cd app && yarn install --frozen-lockfile',
    config = function()
      vim.g.mkdp_filetypes = { 'markdown' }
      vim.g.mkdp_browser = 'zen-beta'
      vim.api.nvim_set_keymap('n', '<leader>md', '<Plug>MarkdownPreviewToggle', { noremap = true, silent = true })
    end,
  },

  require 'kickstart.plugins.debug',
  require 'kickstart.plugins.neo-tree',

  { import = 'custom.plugins' }, -- lua/custom/plugins/*.lua
}, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})
