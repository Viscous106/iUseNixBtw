-- Yanky.nvim - yank history
return {
  'gbprod/yanky.nvim',
  lazy = false,
  config = function()
    require('yanky').setup {
      ring = {
        storage = 'shada',
      },
    }

    vim.keymap.set('n', '<leader>y', function()
      require('telescope').extensions.yank_history.yank_history()
    end, { desc = '[Y]ank history' })
  end,
  keys = {
    { 'p', '<Plug>(YankyPutAfter)', mode = { 'n', 'x' } },
    { 'P', '<Plug>(YankyPutBefore)', mode = { 'n', 'x' } },
  },
}
