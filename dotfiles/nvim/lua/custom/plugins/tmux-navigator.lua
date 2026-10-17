-- vim-tmux-navigator - seamless navigation between tmux and vim
return {
  'christoomey/vim-tmux-navigator',
  lazy = false,
  config = function()
    -- The plugin's default terminal-mode maps use "<C-w>:" which assumes
    -- <C-w> is a terminal window prefix. Neovim does NOT do that by default,
    -- so inside a :terminal (e.g. the Claude Code split) the keys leak into
    -- the program as literal text like "TmuxNavigateLeft". Override with
    -- <Cmd> maps that run the command directly and never touch <C-w>.
    for key, dir in pairs { ['<C-h>'] = 'Left', ['<C-j>'] = 'Down', ['<C-k>'] = 'Up', ['<C-l>'] = 'Right' } do
      vim.keymap.set('t', key, '<Cmd>TmuxNavigate' .. dir .. '<CR>', { silent = true, desc = 'Tmux navigate ' .. dir })
    end
  end,
}
