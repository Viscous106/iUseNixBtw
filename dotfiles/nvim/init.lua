-- Neovim config (fork of kickstart.nvim). Core: lua/config/; extra plugins: lua/custom/plugins/.

-- Leader must be set before plugins load.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.fn.serverstart()

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'config.lazy'
require 'config.notebook'

-- vim: ts=2 sts=2 sw=2 et
