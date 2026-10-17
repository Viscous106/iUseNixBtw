-- silicon - code screenshots via CLI
return {
  'segeljakt/vim-silicon',
  config = function()
    vim.g.silicon = {
      theme = 'Dracula',
      font = 'CaskaydiaCove Nerd Font',
      background = '#aaaaff',
      ['pad-horiz'] = 60,
      ['pad-vert'] = 60,
      ['round-corner'] = true,
      ['window-controls'] = true,
      ['line-number'] = true,
      output = vim.fn.expand '~' .. '/Pictures/Screenshots/silicon-{time:%Y-%m-%d-%H%M%S}.png',
    }

    vim.keymap.set('x', '<leader>pc', function()
      -- grab lines while still in visual mode
      local s = vim.fn.line 'v'
      local e = vim.fn.line '.'
      if s > e then s, e = e, s end
      local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
      local ft = vim.bo.filetype
      local tmp_in = '/tmp/silicon_input.' .. ft
      local tmp_out = '/tmp/silicon_snap.png'

      -- write selected lines to temp file
      vim.fn.writefile(lines, tmp_in)

      local cmd = string.format(
        'DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 '
        .. '/home/viscous/.cargo/bin/silicon %s --language %s -o %s '
        .. '&& DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/1000 '
        .. 'wl-copy --type image/png < %s',
        tmp_in, ft, tmp_out, tmp_out
      )
      vim.fn.jobstart(cmd, {
        detach = true,
        on_exit = function(_, code)
          if code == 0 then
            vim.schedule(function() vim.notify('Snapshot copied to clipboard!') end)
          else
            vim.schedule(function() vim.notify('Silicon failed — check :messages', vim.log.levels.ERROR) end)
          end
        end,
      })
    end, { desc = '[P]hoto [C]lipboard snapshot' })
  end,
}
