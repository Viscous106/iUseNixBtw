-- nvim-gdb - GDB integration for assembly debugging
return {
  'sakhnik/nvim-gdb',
  lazy = false,
  build = ':!./install.sh',
  init = function()
    -- disable default keymaps so we set our own
    vim.g.nvimgdb_disable_start_keymaps = 1
  end,
  config = function()
    -- init string: quiet mode + enable disassembly + show regs layout
    vim.g.nvimgdb_config_override = {
      key_next        = '<F10>',
      key_step        = '<F11>',
      key_finish      = '<F12>',
      key_continue    = '<F5>',
      key_until       = '<F4>',
      key_breakpoint  = '<F8>',
      key_frameup     = '<F6>',
      key_framedown   = '<F7>',
      set_tkeymaps    = 'NvimGdbSetTKeymaps',
    }

    -- <leader>db: start gdb on binary (prompts for path)
    vim.keymap.set('n', '<leader>db', function()
      local bin = vim.fn.input('Binary: ', vim.fn.expand '%:p:r', 'file')
      if bin ~= '' then
        vim.cmd('GdbStart gdb -q ' .. bin)
      end
    end, { desc = '[D]ebug [B]inary with gdb' })

    -- <leader>da: start gdb + auto-switch to asm+regs layout
    vim.keymap.set('n', '<leader>da', function()
      local bin = vim.fn.input('Binary: ', vim.fn.expand '%:p:r', 'file')
      if bin ~= '' then
        vim.cmd('GdbStart gdb -q -ex "set disassemble-next-line on" -ex "layout split" -ex "layout regs" ' .. bin)
      end
    end, { desc = '[D]ebug [A]ssembly layout (asm+regs)' })
  end,
}
