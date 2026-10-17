-- Noice.nvim - modern UI for messages, cmdline, and popups
return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  dependencies = {
    'MunifTanjim/nui.nvim',
    'rcarriga/nvim-notify',
  },
  opts = {
    lsp = {
      override = {
        ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
        ['vim.lsp.util.stylize_markdown'] = true,
        ['cmp.entry.get_documentation'] = true,
      },
    },
    presets = {
      bottom_search = true,
      command_palette = true,
      long_message_to_split = true,
      inc_rename = false,
      lsp_doc_border = false,
    },
  },
  keys = {
    {
      '<leader>nl',
      '<cmd>Noice last<cr>',
      desc = '[N]oice [L]ast message',
    },
    {
      '<leader>nh',
      '<cmd>Noice history<cr>',
      desc = '[N]oice [H]istory',
    },
    {
      '<leader>na',
      '<cmd>Noice all<cr>',
      desc = '[N]oice [A]ll',
    },
    {
      '<leader>nd',
      '<cmd>Noice dismiss<cr>',
      desc = '[N]oice [D]ismiss',
    },
  },
}
