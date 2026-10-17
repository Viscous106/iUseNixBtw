-- Multicursor.nvim - VS Code style multicursor editing
return {
  'jake-stewart/multicursor.nvim',
  branch = '1.0',
  config = function()
    local mc = require 'multicursor-nvim'
    mc.setup()

    -- Keymaps
    vim.keymap.set({ 'n', 'v' }, '<c-d>', function()
      mc.matchAddCursor()
    end, { desc = 'Add cursor at next match' })

    vim.keymap.set({ 'n', 'v' }, '<c-s>', function()
      mc.matchSkipCursor()
    end, { desc = 'Skip to next match' })

    vim.keymap.set({ 'n', 'v' }, '<c-x>', function()
      mc.deleteCursor()
    end, { desc = 'Delete current cursor' })

    vim.keymap.set('n', '<esc>', function()
      if not mc.cursorsEnabled() then
        mc.enableCursors()
      elseif mc.hasCursors() then
        mc.clearCursors()
      else
        vim.cmd 'nohlsearch'
      end
    end, { desc = 'Clear multicursor' })
  end,
}
