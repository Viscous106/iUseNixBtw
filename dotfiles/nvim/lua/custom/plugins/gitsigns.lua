-- Gitsigns - git integration (advanced)
return {
  'lewis6991/gitsigns.nvim',
  event = { 'BufReadPre', 'BufNewFile' },
  opts = {
    signs = {
      add = { text = '+' },
      change = { text = '~' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
    },
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns

      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      -- Navigation
      map('n', ']c', function()
        if vim.wo.diff then
          return ']c'
        end
        vim.schedule(function()
          gs.next_hunk()
        end)
        return '<Ignore>'
      end, { expr = true, desc = 'Next hunk' })

      map('n', '[c', function()
        if vim.wo.diff then
          return '[c'
        end
        vim.schedule(function()
          gs.prev_hunk()
        end)
        return '<Ignore>'
      end, { expr = true, desc = 'Previous hunk' })

      -- Actions
      map('n', '<leader>gb', gs.blame_line, { desc = '[G]it [B]lame line' })
      map('n', '<leader>gB', gs.toggle_current_line_blame, { desc = '[G]it [B]lame toggle' })
      map('n', '<leader>gd', gs.diffthis, { desc = '[G]it [D]iff this' })
      map('n', '<leader>gD', function()
        gs.diffthis '~'
      end, { desc = '[G]it [D]iff HEAD' })
      map('n', '<leader>gp', gs.preview_hunk, { desc = '[G]it [P]review hunk' })
      map('n', '<leader>gr', gs.reset_hunk, { desc = '[G]it [R]eset hunk' })
      map('n', '<leader>gR', gs.reset_buffer, { desc = '[G]it [R]eset buffer' })
      map('n', '<leader>gs', gs.stage_hunk, { desc = '[G]it [S]tage hunk' })
      map('n', '<leader>gu', gs.undo_stage_hunk, { desc = '[G]it [U]ndo stage hunk' })

      -- Text object
      map({ 'o', 'x' }, 'ig', ':<C-U>Gitsigns select_hunk<CR>', { desc = 'Gitsigns select hunk' })
    end,
  },
}
