-- Keymaps not tied to a plugin.
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>cl', '<cmd>messages clear<CR>', { desc = '[C]lear messages' })

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- splits
vim.keymap.set('n', '<leader>\\', '<cmd>vsplit<CR>', { desc = 'Split window vertically' })
vim.keymap.set('n', '<leader>-', '<cmd>split<CR>', { desc = 'Split window horizontally' })

vim.keymap.set('n', '<localleader>jv', function()
  local file = vim.fn.expand '%:p'
  if vim.fn.expand '%:e' == 'ipynb' then
    vim.cmd('terminal view-notebook ' .. file)
  else
    vim.notify('Only works on .ipynb files', vim.log.levels.WARN)
  end
end, { desc = '[J]upyter [V]iew notebook (interactive)' })

vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- CTRL+hjkl window navigation comes from vim-tmux-navigator.

-- window resizing
vim.keymap.set('n', '<C-Up>', ':resize +2<CR>', { desc = 'Increase window height', silent = true })
vim.keymap.set('n', '<C-Down>', ':resize -2<CR>', { desc = 'Decrease window height', silent = true })
vim.keymap.set('n', '<C-Left>', ':vertical resize -2<CR>', { desc = 'Decrease window width', silent = true })
vim.keymap.set('n', '<C-Right>', ':vertical resize +2<CR>', { desc = 'Increase window width', silent = true })

vim.keymap.set('n', '<M-k>', ':resize +5<CR>', { desc = 'Increase window height (fast)', silent = true })
vim.keymap.set('n', '<M-j>', ':resize -5<CR>', { desc = 'Decrease window height (fast)', silent = true })
vim.keymap.set('n', '<M-h>', ':vertical resize -5<CR>', { desc = 'Decrease window width (fast)', silent = true })
vim.keymap.set('n', '<M-l>', ':vertical resize +5<CR>', { desc = 'Increase window width (fast)', silent = true })

-- Terminal/browser-like word navigation and deletion in insert mode
vim.keymap.set('i', '<M-BS>', '<C-w>', { desc = 'Delete word backward' })
vim.keymap.set('i', '<C-Left>', '<C-o>b', { desc = 'Move word backward' })
vim.keymap.set('i', '<C-Right>', '<C-o>w', { desc = 'Move word forward' })
