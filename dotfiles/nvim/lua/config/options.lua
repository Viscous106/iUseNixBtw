vim.g.netrw_browsex_viewer = 'zen-beta'

vim.g.have_nerd_font = true

-- Disable optional remote-host providers we don't use (silences :checkhealth
-- warnings for Node/Perl/Ruby). Clipboard is handled natively via wl-copy.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- python3 provider for molten-nvim (needs pynvim). Built in home/dev/neovim.nix as
-- `nvim-python3-host`; withPython3 is off there since it would generate a competing init.lua.
local python3_host = vim.fn.exepath 'nvim-python3-host'
if python3_host ~= '' then
  vim.g.python3_host_prog = python3_host
else
  vim.g.loaded_python3_provider = 0
end

-- [[ Options ]]
vim.o.number = true
vim.o.mouse = 'a'
vim.o.showmode = false -- shown in the statusline

-- System clipboard via wl-clipboard; scheduled since it can slow startup.
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
  vim.env.WAYLAND_DISPLAY = vim.env.WAYLAND_DISPLAY or 'wayland-1'
  vim.env.XDG_RUNTIME_DIR = vim.env.XDG_RUNTIME_DIR or '/run/user/1000'
  vim.g.clipboard = {
    name = 'wl-clipboard',
    copy = {
      ['+'] = { 'wl-copy' },
      ['*'] = { 'wl-copy', '--primary' },
    },
    paste = {
      ['+'] = { 'wl-paste', '--no-newline' },
      ['*'] = { 'wl-paste', '--no-newline', '--primary' },
    },
    cache_enabled = 1,
  }
end)

vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.scrolloff = 10
vim.o.confirm = true -- prompt to save instead of failing on :q
