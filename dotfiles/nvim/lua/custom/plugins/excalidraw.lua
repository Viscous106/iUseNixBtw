-- markdown-excalidraw.nvim - edit .excalidraw files in the browser, auto-saved back to disk
return {
  'Cosipa/markdown-excalidraw.nvim',
  cmd = { 'ExcalidrawOpen', 'ExcalidrawCreate', 'ExcalidrawStatus', 'ExcalidrawStop' },
  keys = {
    { '<leader>eo', '<cmd>ExcalidrawOpen<CR>', desc = '[E]xcalidraw [O]pen' },
    { '<leader>en', '<cmd>ExcalidrawCreate<CR>', desc = '[E]xcalidraw [N]ew' },
    { '<leader>es', '<cmd>ExcalidrawStatus<CR>', desc = '[E]xcalidraw [S]tatus' },
    { '<leader>eq', '<cmd>ExcalidrawStop<CR>', desc = '[E]xcalidraw [Q]uit server' },
  },
  opts = {
    auto_open = false, -- plugin is lazy; open explicitly with <leader>eo
    theme = 'light', -- matches the coloured hand-drawn look
  },
}
