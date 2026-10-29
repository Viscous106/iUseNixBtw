-- New files start from skeletons/<filename> or skeletons/skeleton.<ext>; {{name}}, {{NAME}}, {{cursor}} get filled in.
local dir = vim.fn.stdpath 'config' .. '/skeletons/'

vim.api.nvim_create_autocmd('BufNewFile', {
  desc = 'Insert language boilerplate into new files',
  group = vim.api.nvim_create_augroup('skeletons', { clear = true }),
  callback = function(args)
    if vim.bo[args.buf].buftype ~= '' then
      return
    end
    local path = vim.api.nvim_buf_get_name(args.buf)
    local tpl = dir .. vim.fn.fnamemodify(path, ':t')
    if vim.fn.filereadable(tpl) == 0 then
      tpl = dir .. 'skeleton.' .. vim.fn.fnamemodify(path, ':e')
      if vim.fn.filereadable(tpl) == 0 then
        return
      end
    end

    local name = vim.fn.fnamemodify(path, ':t:r')
    local NAME = (name:upper():gsub('[^%w]', '_'))
    local lines, cursor = vim.fn.readfile(tpl), nil
    for i, line in ipairs(lines) do
      line = line:gsub('{{name}}', function() return name end):gsub('{{NAME}}', function() return NAME end)
      local col = line:find('{{cursor}}', 1, true)
      if col then
        cursor = { i, col - 1 }
        line = line:sub(1, col - 1) .. line:sub(col + #'{{cursor}}')
      end
      lines[i] = line
    end

    vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, lines)
    if cursor and args.buf == vim.api.nvim_get_current_buf() then
      vim.api.nvim_win_set_cursor(0, cursor)
    end
  end,
})
