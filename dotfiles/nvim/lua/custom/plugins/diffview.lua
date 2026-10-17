-- diffview
return {
  'sindrets/diffview.nvim',
  config = function()
    vim.keymap.set('n', '<leader>dv', ':DiffviewOpen<CR>', { desc = 'Diffview open' })
    vim.keymap.set('n', '<leader>dc', ':DiffviewClose<CR>', { desc = 'Diffview close' })
  end,
}
