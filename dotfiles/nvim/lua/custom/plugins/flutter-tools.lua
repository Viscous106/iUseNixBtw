-- flutter-tools.nvim - full Flutter/Dart IDE (manages dartls itself)
return {
  'akinsho/flutter-tools.nvim',
  lazy = false,
  ft = { 'dart' },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'mfussenegger/nvim-dap', -- debugging (nvim-dap-ui comes from kickstart debug plugin)
  },
  config = function()
    require('flutter-tools').setup {
      flutter_path = '/opt/flutter/bin/flutter',
      lsp = {
        capabilities = require('blink.cmp').get_lsp_capabilities(),
        on_attach = function(_, bufnr)
          local map = function(keys, cmd, desc)
            vim.keymap.set('n', keys, cmd, { buffer = bufnr, desc = 'Flutter: ' .. desc })
          end
          map('<leader>Fr', '<cmd>FlutterRun<CR>', '[R]un')
          map('<leader>Fq', '<cmd>FlutterQuit<CR>', '[Q]uit')
          map('<leader>Fh', '<cmd>FlutterReload<CR>', 'Hot reload')
          map('<leader>FR', '<cmd>FlutterRestart<CR>', 'Hot [R]estart')
          map('<leader>Fd', '<cmd>FlutterDevices<CR>', '[D]evices')
          map('<leader>Fe', '<cmd>FlutterEmulators<CR>', '[E]mulators')
          map('<leader>Fo', '<cmd>FlutterOutlineToggle<CR>', '[O]utline')
          map('<leader>Fl', '<cmd>FlutterLogClear<CR>', '[L]og clear')
          -- Live app window on the Linux desktop (hot-reloads on save)
          map('<leader>Fp', '<cmd>FlutterRun -d linux<CR>', 'Live [P]review (desktop window)')
          -- Widget-level preview environment (renders @Preview() widgets in a browser)
          map('<leader>FP', function()
            vim.cmd 'botright vsplit | terminal flutter widget-preview start'
            vim.cmd 'startinsert'
          end, 'Widget [P]review env (browser)')
        end,
        settings = {
          showTodos = true,
          renameFilesWithClasses = 'prompt',
          updateImportsOnRename = true,
          completeFunctionCalls = true,
        },
      },
      debugger = {
        enabled = true,
        run_via_dap = true,
        register_configurations = function(_)
          require('dap').configurations.dart = {}
          require('dap.ext.vscode').load_launchjs()
        end,
      },
      widget_guides = { enabled = true },
      closing_tags = { enabled = true, highlight = 'Comment', prefix = '// ' },
      dev_log = { enabled = true, open_cmd = 'tabedit' },
    }
  end,
}
