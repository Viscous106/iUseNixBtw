-- leetcode.nvim - solve LeetCode inside Neovim (dashboard, run/submit, image diagrams)
return {
  'kawre/leetcode.nvim',
  build = ':TSUpdate html', -- description pane renders the problem HTML
  lazy = false, -- so `nvim leetcode.nvim` opens straight to the dashboard
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'MunifTanjim/nui.nvim',
    'nvim-lua/plenary.nvim',
    '3rd/image.nvim', -- inline problem diagrams via your existing kitty backend
  },
  opts = {
    arg = 'leetcode.nvim', -- launch: `nvim leetcode.nvim`
    lang = 'rust',
    cn = { enabled = false }, -- leetcode.com (global), not leetcode.cn
    image_support = true,
  },
  keys = {
    { '<leader>Ld', '<cmd>Leet<cr>', desc = '[L]eetCode [D]ashboard/menu' },
    { '<leader>Ll', '<cmd>Leet list<cr>', desc = '[L]eetCode problem [L]ist' },
    { '<leader>Lr', '<cmd>Leet run<cr>', desc = '[L]eetCode [R]un tests' },
    { '<leader>Ls', '<cmd>Leet submit<cr>', desc = '[L]eetCode [S]ubmit' },
    { '<leader>Lc', '<cmd>Leet console<cr>', desc = '[L]eetCode [C]onsole' },
    { '<leader>Li', '<cmd>Leet info<cr>', desc = '[L]eetCode problem [I]nfo' },
    { '<leader>Lo', '<cmd>Leet open<cr>', desc = '[L]eetCode [O]pen in browser' },
    { '<leader>Lt', '<cmd>Leet desc<cr>', desc = '[L]eetCode [T]oggle description' },
    { '<leader>LD', '<cmd>Leet daily<cr>', desc = '[L]eetCode [D]aily challenge' },
    { '<leader>LR', '<cmd>Leet random<cr>', desc = '[L]eetCode [R]andom problem' },
    { '<leader>Ly', '<cmd>Leet yank<cr>', desc = '[L]eetCode [Y]ank solution' },
  },
}
