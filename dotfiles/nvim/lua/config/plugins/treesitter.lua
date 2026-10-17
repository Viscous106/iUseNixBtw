-- Highlight, edit, and navigate code.
return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  build = ':TSUpdate',
  lazy = false,
  config = function()
    -- `main` branch ignores ensure_installed/highlight/indent in setup(), so parsers
    -- are installed explicitly and highlighting is started per buffer.
    local ensure_installed = {
      'bash',
      'c',
      'css',
      'dart',
      'diff',
      'html',
      'javascript',
      'jsdoc',
      'json',
      'lua',
      'luadoc',
      'markdown',
      'markdown_inline',
      'query',
      'solidity',
      'tsx',
      'typescript',
      'vim',
      'vimdoc',
      'xml',
    }

    local installed = require('nvim-treesitter.config').get_installed 'parsers'
    local missing = vim.tbl_filter(function(lang)
      return not vim.tbl_contains(installed, lang)
    end, ensure_installed)
    if #missing > 0 then
      require('nvim-treesitter').install(missing)
    end

    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('kickstart-treesitter', { clear = true }),
      callback = function(args)
        -- no parser -> keep regular syntax highlighting
        if not pcall(vim.treesitter.start, args.buf) then
          return
        end
        if vim.bo[args.buf].filetype ~= 'ruby' then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
