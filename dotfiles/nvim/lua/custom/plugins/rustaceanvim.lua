-- rustaceanvim - full Rust IDE experience via rust-analyzer
return {
  'mrcjkb/rustaceanvim',
  version = '^5',
  lazy = false,
  ft = { 'rust' },
  config = function()
    local codelldb_path = vim.fn.stdpath 'data' .. '/mason/packages/codelldb/extension/adapter/codelldb'
    local liblldb_path = vim.fn.stdpath 'data' .. '/mason/packages/codelldb/extension/lldb/lib/liblldb.so'

    vim.g.rustaceanvim = {
      tools = {
        hover_actions = { auto_focus = true },
      },
      server = {
        on_attach = function(_, bufnr)
          local map = function(keys, func, desc)
            vim.keymap.set('n', keys, func, { buffer = bufnr, desc = 'Rust: ' .. desc })
          end

          map('<leader>rr', function() vim.cmd.RustLsp 'runnables' end, '[R]unnables')
          map('<leader>rt', function() vim.cmd.RustLsp 'testables' end, '[T]estables')
          map('<leader>rd', function() vim.cmd.RustLsp 'debuggables' end, '[D]ebuggables')
          map('<leader>re', function() vim.cmd.RustLsp 'expandMacro' end, '[E]xpand macro')
          map('<leader>rc', function() vim.cmd.RustLsp 'openCargo' end, 'Open [C]argo.toml')
          map('<leader>rp', function() vim.cmd.RustLsp 'parentModule' end, '[P]arent module')
          map('<leader>rh', function() vim.cmd.RustLsp { 'hover', 'actions' } end, '[H]over actions')
          map('<leader>ra', function() vim.cmd.RustLsp 'codeAction' end, 'Code [A]ction')
          map('<leader>rD', function() vim.cmd.RustLsp 'renderDiagnostic' end, 'Render [D]iagnostic')
        end,
        settings = {
          ['rust-analyzer'] = {
            cargo = { allFeatures = true },
            checkOnSave = { command = 'clippy' },
            inlayHints = {
              bindingModeHints = { enable = true },
              closureReturnTypeHints = { enable = 'always' },
              lifetimeElisionHints = { enable = 'skip_trivial' },
            },
          },
        },
      },
      dap = {
        adapter = require('rustaceanvim.config').get_codelldb_adapter(codelldb_path, liblldb_path),
      },
    }

    -- rustfmt on save
    vim.api.nvim_create_autocmd('BufWritePre', {
      pattern = '*.rs',
      callback = function()
        vim.lsp.buf.format { async = false }
      end,
    })
  end,
}
