-- Spectre.nvim - find and replace
return {
  'nvim-pack/nvim-spectre',
  dependencies = { 'nvim-lua/plenary.nvim' },
  cmd = 'Spectre',
  keys = {
    {
      '<leader>S',
      '<cmd>Spectre<CR>',
      desc = '[S]pectre open',
    },
    {
      '<leader>sW',
      function()
        require('spectre').open_visual { select_word = true }
      end,
      desc = '[S]pectre search current [W]ord',
    },
  },
  opts = {
    open_cmd = 'noswapfile vnew',
  },
}
