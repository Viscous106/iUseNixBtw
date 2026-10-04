return {
  -- silicon - code screenshots via CLI
  {
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
  },

  -- rustaceanvim - full Rust IDE experience via rust-analyzer
  {
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
  },

  -- flutter-tools.nvim - full Flutter/Dart IDE (manages dartls itself)
  {
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
  },

  -- pubspec-assist.nvim - manage pubspec.yaml dependencies
  {
    'akinsho/pubspec-assist.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    ft = { 'yaml' },
    event = 'BufRead pubspec.yaml',
    config = true,
  },

  -- nvim-gdb - GDB integration for assembly debugging
  {
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
  },

  -- vim-tmux-navigator - seamless navigation between tmux and vim
  {
    'christoomey/vim-tmux-navigator',
    lazy = false,
    config = function()
      -- The plugin's default terminal-mode maps use "<C-w>:" which assumes
      -- <C-w> is a terminal window prefix. Neovim does NOT do that by default,
      -- so inside a :terminal (e.g. the Claude Code split) the keys leak into
      -- the program as literal text like "TmuxNavigateLeft". Override with
      -- <Cmd> maps that run the command directly and never touch <C-w>.
      for key, dir in pairs { ['<C-h>'] = 'Left', ['<C-j>'] = 'Down', ['<C-k>'] = 'Up', ['<C-l>'] = 'Right' } do
        vim.keymap.set('t', key, '<Cmd>TmuxNavigate' .. dir .. '<CR>', { silent = true, desc = 'Tmux navigate ' .. dir })
      end
    end,
  },

  -- Fugitive
  'tpope/vim-fugitive',

  -- diffview
  {
    'sindrets/diffview.nvim',
    config = function()
      vim.keymap.set('n', '<leader>dv', ':DiffviewOpen<CR>', { desc = 'Diffview open' })
      vim.keymap.set('n', '<leader>dc', ':DiffviewClose<CR>', { desc = 'Diffview close' })
    end,
  },

  -- lualine
  {
    'nvim-lualine/lualine.nvim',
    config = function()
      require('lualine').setup {
        options = {
          icons_enabled = vim.g.have_nerd_font,
          theme = 'auto',
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
          disabled_filetypes = {
            statusline = {},
            winbar = {},
          },
          ignore_focus = {},
          always_divide_middle = true,
          globalstatus = false,
          refresh = {
            statusline = 1000,
            tabline = 1000,
            winbar = 1000,
          },
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff', 'diagnostics' },
          lualine_c = { 'filename' },
          lualine_x = { 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { 'filename' },
          lualine_x = { 'location' },
          lualine_y = {},
          lualine_z = {},
        },
        tabline = {},
        winbar = {},
        inactive_winbar = {},
        extensions = {},
      }
    end,
  },

  -- live-server
  {
    'barrett-ruth/live-server.nvim',
    build = 'npm install -g live-server',
    cmd = { 'LiveServerStart', 'LiveServerStop', 'LiveServerToggle' },
    keys = {
      { '<leader>ls', '<cmd>LiveServerToggle<CR>', desc = '[L]ive [S]erver toggle' },
    },
    config = true,
  },

  -- Claude Code integration (replaces GitHub Copilot / CopilotChat)
  {
    'coder/claudecode.nvim',
    config = true,
    keys = {
      -- Core
      { '<leader>cc', '<cmd>ClaudeCode<cr>', desc = '[C]laude [C]ode toggle' },
      { '<leader>cf', '<cmd>ClaudeCodeFocus<cr>', desc = '[C]laude [F]ocus window' },
      { '<leader>cr', '<cmd>ClaudeCode --resume<cr>', desc = '[C]laude [R]esume session' },
      { '<leader>cC', '<cmd>ClaudeCode --continue<cr>', desc = '[C]laude [C]ontinue session' },
      { '<leader>cm', '<cmd>ClaudeCodeSelectModel<cr>', desc = '[C]laude select [M]odel' },

      -- Add context
      { '<leader>cb', '<cmd>ClaudeCodeAdd %<cr>', desc = '[C]laude add [B]uffer' },
      { '<leader>cs', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = '[C]laude [S]end selection' },
      {
        '<leader>cs',
        '<cmd>ClaudeCodeTreeAdd<cr>',
        desc = '[C]laude add file from tree',
        ft = { 'NvimTree', 'neo-tree', 'oil', 'minifiles' },
      },

      -- Diff management (accept/reject Claude's proposed edits)
      { '<leader>ca', '<cmd>ClaudeCodeDiffAccept<cr>', desc = '[C]laude [A]ccept diff' },
      { '<leader>cd', '<cmd>ClaudeCodeDiffDeny<cr>', desc = '[C]laude [D]eny diff' },
    },
  },

  -- Auto-pairs - automatically close brackets, quotes, etc.
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = function()
      require('nvim-autopairs').setup {}
    end,
  },

  -- Auto-close/rename HTML & JSX tags: typing `<div>` inserts `</div>`, and
  -- renaming an opening tag renames its closing tag. Treesitter-driven, so the
  -- parser for the filetype has to be installed (see `ensure_installed` in init.lua).
  {
    'windwp/nvim-ts-autotag',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    ft = {
      'html',
      'xml',
      'javascript',
      'javascriptreact',
      'typescript',
      'typescriptreact',
      'svelte',
      'vue',
      'astro',
      'php',
      'markdown',
      'htmldjango',
      'handlebars',
      'eruby',
    },
    opts = {
      opts = {
        enable_close = true, -- `<div` + `>` auto-inserts `</div>`
        enable_rename = true, -- renaming the opening tag renames the closing one
        enable_close_on_slash = false, -- don't auto-close when typing `</`
      },
    },
  },

  -- Toggleterm - better terminal integration
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function()
      require('toggleterm').setup {
        size = 20,
        open_mapping = [[<c-\>]],
        hide_numbers = true,
        shade_terminals = true,
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        persist_size = true,
        direction = 'float', -- 'vertical' | 'horizontal' | 'tab' | 'float'
        close_on_exit = true,
        shell = vim.o.shell,
        float_opts = {
          border = 'curved',
          winblend = 0,
        },
      }
    end,
  },

  -- Flash.nvim - super fast navigation
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      {
        's',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').jump()
        end,
        desc = 'Flash',
      },
      {
        'S',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').treesitter()
        end,
        desc = 'Flash Treesitter',
      },
      {
        'r',
        mode = 'o',
        function()
          require('flash').remote()
        end,
        desc = 'Remote Flash',
      },
      {
        'R',
        mode = { 'o', 'x' },
        function()
          require('flash').treesitter_search()
        end,
        desc = 'Treesitter Search',
      },
      {
        '<c-s>',
        mode = { 'c' },
        function()
          require('flash').toggle()
        end,
        desc = 'Toggle Flash Search',
      },
    },
  },

  -- Harpoon - quick file bookmarking
  {
    'ThePrimeagen/harpoon',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local harpoon = require 'harpoon'
      harpoon:setup {
        settings = {
          save_on_toggle = true,
          sync_on_ui_close = true,
        },
      }

      -- Keymaps
      vim.keymap.set('n', '<leader>a', function()
        harpoon:list():add()
      end, { desc = 'H[a]rpoon add file' })

      vim.keymap.set('n', '<leader>hh', function()
        harpoon.ui:toggle_quick_menu(harpoon:list())
      end, { desc = '[H]arpoon menu' })

      vim.keymap.set('n', '<leader>hc', function()
        harpoon:list():clear()
      end, { desc = '[H]arpoon [c]lear all' })

      -- Quick access to first 4 files
      vim.keymap.set('n', '<leader>1', function()
        harpoon:list():select(1)
      end, { desc = 'Harpoon file 1' })
      vim.keymap.set('n', '<leader>2', function()
        harpoon:list():select(2)
      end, { desc = 'Harpoon file 2' })
      vim.keymap.set('n', '<leader>3', function()
        harpoon:list():select(3)
      end, { desc = 'Harpoon file 3' })
      vim.keymap.set('n', '<leader>4', function()
        harpoon:list():select(4)
      end, { desc = 'Harpoon file 4' })

      -- Navigate through harpoon list
      vim.keymap.set('n', '<leader>hp', function()
        harpoon:list():prev()
      end, { desc = '[H]arpoon [p]revious' })
      vim.keymap.set('n', '<leader>hn', function()
        harpoon:list():next()
      end, { desc = '[H]arpoon [n]ext' })
    end,
  },

  -- Trouble.nvim - beautiful diagnostics panel
  {
    'folke/trouble.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    cmd = 'Trouble',
    keys = {
      {
        '<leader>xx',
        '<cmd>Trouble diagnostics toggle<cr>',
        desc = 'Diagnostics (Trouble)',
      },
      {
        '<leader>xX',
        '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
        desc = 'Buffer Diagnostics (Trouble)',
      },
      {
        '<leader>xs',
        '<cmd>Trouble symbols toggle focus=false<cr>',
        desc = 'Symbols (Trouble)',
      },
      {
        '<leader>xl',
        '<cmd>Trouble lsp toggle focus=false win.position=right<cr>',
        desc = 'LSP Definitions / references / ... (Trouble)',
      },
      {
        '<leader>xL',
        '<cmd>Trouble loclist toggle<cr>',
        desc = 'Location List (Trouble)',
      },
      {
        '<leader>xQ',
        '<cmd>Trouble qflist toggle<cr>',
        desc = 'Quickfix List (Trouble)',
      },
    },
    opts = {},
  },

  -- Noice.nvim - modern UI for messages, cmdline, and popups
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    dependencies = {
      'MunifTanjim/nui.nvim',
      'rcarriga/nvim-notify',
    },
    opts = {
      lsp = {
        override = {
          ['vim.lsp.util.convert_input_to_markdown_lines'] = true,
          ['vim.lsp.util.stylize_markdown'] = true,
          ['cmp.entry.get_documentation'] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = false,
        lsp_doc_border = false,
      },
    },
    keys = {
      {
        '<leader>nl',
        '<cmd>Noice last<cr>',
        desc = '[N]oice [L]ast message',
      },
      {
        '<leader>nh',
        '<cmd>Noice history<cr>',
        desc = '[N]oice [H]istory',
      },
      {
        '<leader>na',
        '<cmd>Noice all<cr>',
        desc = '[N]oice [A]ll',
      },
      {
        '<leader>nd',
        '<cmd>Noice dismiss<cr>',
        desc = '[N]oice [D]ismiss',
      },
    },
  },

  -- Alpha - startup dashboard
  {
    'goolord/alpha-nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local alpha = require 'alpha'
      local dashboard = require 'alpha.themes.dashboard'

      -- Custom header
      dashboard.section.header.val = {
        '                                                     ',
        '  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗',
        '  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║',
        '  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║',
        '  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║',
        '  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║',
        '  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝',
        '                                                     ',
      }

      -- Set menu buttons
      dashboard.section.buttons.val = {
        dashboard.button('f', '  Find file', ':Telescope find_files <CR>'),
        dashboard.button('e', '  New file', ':ene <BAR> startinsert <CR>'),
        dashboard.button('r', '  Recent files', ':Telescope oldfiles <CR>'),
        dashboard.button('g', '  Find text', ':Telescope live_grep <CR>'),
        dashboard.button('c', '  Config', ':e ~/.config/nvim/init.lua <CR>'),
        dashboard.button('q', '  Quit', ':qa<CR>'),
      }

      -- Git status function
      local function get_git_status()
        local branch = vim.fn.system("git branch --show-current 2>/dev/null | tr -d '\n'")
        if vim.v.shell_error ~= 0 or branch == '' then
          return '  Not a git repo'
        end
        
        local status = vim.fn.system("git status --porcelain 2>/dev/null | wc -l | tr -d ' \n'")
        local changes = tonumber(status) or 0
        
        if changes == 0 then
          return '  ' .. branch .. ' (clean)'
        else
          return '  ' .. branch .. ' (' .. changes .. ' changes)'
        end
      end

      -- Stats footer function
      local function get_stats()
        local total_plugins = #vim.tbl_keys(require('lazy').plugins())
        local datetime = os.date '  %Y-%m-%d   %H:%M:%S'
        local version = vim.version()
        local nvim_version = '  Neovim v' .. version.major .. '.' .. version.minor .. '.' .. version.patch
        
        return {
          datetime,
          nvim_version .. '   ' .. total_plugins .. ' plugins',
        }
      end

      -- Footer with git status and stats
      local git_status = get_git_status()
      local stats = get_stats()
      
      dashboard.section.footer.val = vim.list_extend({ '', git_status, '' }, stats)

      -- Color customization
      dashboard.section.header.opts.hl = 'Type'
      dashboard.section.buttons.opts.hl = 'Keyword'
      dashboard.section.footer.opts.hl = 'Comment'

      -- Layout configuration (centered with spacing)
      dashboard.config.layout = {
        { type = 'padding', val = 2 },
        dashboard.section.header,
        { type = 'padding', val = 2 },
        dashboard.section.buttons,
        { type = 'padding', val = 1 },
        dashboard.section.footer,
      }

      -- Send config to alpha
      alpha.setup(dashboard.config)

      -- Disable folding on alpha buffer
      vim.cmd [[autocmd FileType alpha setlocal nofoldenable]]
    end,
  },

  -- Indent Blankline - show indent guides
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      indent = {
        char = '│',
        tab_char = '│',
      },
      scope = { enabled = false },
      exclude = {
        filetypes = {
          'help',
          'alpha',
          'dashboard',
          'neo-tree',
          'Trouble',
          'lazy',
          'mason',
          'notify',
          'toggleterm',
          'lazyterm',
        },
      },
    },
  },

  -- nvim-colorizer - show color previews
  {
    'NvChad/nvim-colorizer.lua',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      require('colorizer').setup {
        filetypes = { '*' },
        user_default_options = {
          RGB = true, -- #RGB hex codes
          RRGGBB = true, -- #RRGGBB hex codes
          names = true, -- "Name" codes like Blue
          RRGGBBAA = true, -- #RRGGBBAA hex codes
          rgb_fn = true, -- CSS rgb() and rgba() functions
          hsl_fn = true, -- CSS hsl() and hsla() functions
          css = true, -- Enable all CSS features
          css_fn = true, -- Enable all CSS *functions*
          mode = 'background', -- Set the display mode (foreground/background)
        },
      }
    end,
  },

  -- Multicursor.nvim - VS Code style multicursor editing
  {
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
  },

  -- Yanky.nvim - yank history
  {
    'gbprod/yanky.nvim',
    lazy = false,
    config = function()
      require('yanky').setup {
        ring = {
          storage = 'shada',
        },
      }

      vim.keymap.set('n', '<leader>y', function()
        require('telescope').extensions.yank_history.yank_history()
      end, { desc = '[Y]ank history' })
    end,
    keys = {
      { 'p', '<Plug>(YankyPutAfter)', mode = { 'n', 'x' } },
      { 'P', '<Plug>(YankyPutBefore)', mode = { 'n', 'x' } },
    },
  },

  -- Spectre.nvim - find and replace
  {
    'nvim-pack/nvim-spectre',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = 'Spectre',
    keys = {
      {
        '<leader>S',
        '<cmd>Spectre<CR>',
        desc = '[S]pectre open',
      },
      {
        '<leader>sW',
        function()
          require('spectre').open_visual { select_word = true }
        end,
        desc = '[S]pectre search current [W]ord',
      },
    },
    opts = {
      open_cmd = 'noswapfile vnew',
    },
  },

  -- Gitsigns - git integration (advanced)
  {
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
  },  -- nvim-ghost.nvim
  { 'subnut/nvim-ghost.nvim', lazy = false },

  -- Molten.nvim - Jupyter notebook support
  {
    'benlubas/molten-nvim',
    version = '^1.0.0',
    lazy = false,
    enabled = true,
    dependencies = { 'benlubas/image.nvim' },
    -- :MoltenInstall is not a thing — molten registers its commands through
    -- the pynvim remote-plugin manifest, which :UpdateRemotePlugins writes.
    build = ':UpdateRemotePlugins',
    config = function()
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_image_provider = 'image.nvim'
      vim.g.molten_virt_text_output = false
      vim.g.molten_virt_lines_off_by_1 = false

      -- Every :Molten* command comes from the pynvim remote-plugin manifest,
      -- which only exists after :UpdateRemotePlugins has run against a python3
      -- host that can import pynvim. Until then the mappings below would fire
      -- a bare "E492: Not an editor command" wrapped in an unreadable Lua
      -- stack trace (E5108 ... nvim_exec2), which says nothing about the
      -- actual cause. Route every mapping through this so the failure names
      -- the fix instead.
      -- Is the remote-plugin manifest loaded at all? Always probe a *command*
      -- (:MoltenInit), never a function: nvim defines rplugin functions
      -- lazily via remote#define#FunctionOnHost, so exists('*MoltenEvaluateRange')
      -- reports 0 right up until the first call even though calling it works
      -- fine. Commands are registered eagerly and do report 2.
      local function molten_ready()
        if vim.fn.exists ':MoltenInit' ~= 2 then
          vim.notify(
            'molten-nvim is not registered (:MoltenInit does not exist).\n'
              .. 'Run :UpdateRemotePlugins, then restart nvim.\n'
              .. 'Still broken? :checkhealth provider — the python3 host needs pynvim.',
            vim.log.levels.ERROR,
            { title = 'molten-nvim' }
          )
          return false
        end

        -- No kernel attached means every mapping below is a silent no-op:
        -- molten's own kernel_check() just pops a picker through vim.ui.select
        -- and gives up if nothing answers, so you press a key and literally
        -- nothing happens. The usual cause is the buffer not being Python at
        -- all — an .ipynb read as raw JSON, because jupytext.nvim is off —
        -- and the autocmd below only auto-attaches to ft=python.
        -- pcall, not exists('*MoltenStatusLineKernels'): same lazy-definition
        -- quirk as above means exists() reports 0 for a function that calls
        -- perfectly well, so testing it would skip this check every time.
        local ok, kernels = pcall(vim.fn.MoltenStatusLineKernels, true)
        if ok and kernels == '' then
          local ft = vim.bo.filetype
          local hint = ft == 'python' and 'Attach one with :MoltenInit'
            or ('This is a ' .. (ft == '' and 'no-filetype' or ft) .. ' buffer, not python'
              .. (ft == 'json' and " — an .ipynb opened as raw JSON means jupytext.nvim is disabled;\n`jupytext` is not on nvim's PATH yet, so run a home-manager switch." or '')
              .. '.\nAttach anyway with :MoltenInit')
          vim.notify(
            'No kernel attached to this buffer.\n' .. hint,
            vim.log.levels.ERROR,
            { title = 'molten-nvim' }
          )
          return false
        end

        return true
      end

      local function molten_cmd(cmd, opts)
        opts = opts or {}
        return function()
          if not molten_ready() then
            return
          end
          -- MoltenEvaluateVisual reads the '< and '> marks, which are only
          -- written when visual mode is left — so drop out of it first.
          if opts.visual then
            vim.cmd 'normal! \27'
          end
          vim.cmd(cmd)
        end
      end

      -- ── Cell support ──────────────────────────────────────────────────
      -- Molten is only an execution engine: it has no idea what a "cell" is
      -- until you evaluate a range, at which point it remembers that range
      -- as one. So :MoltenReevaluateCell can only ever re-run something you
      -- already ran, and on a fresh buffer every output mapping is a no-op.
      -- These helpers supply the missing half — they read `# %%` markers
      -- (jupytext's "hydrogen" style, see the plugin spec above) and hand
      -- molten the line range, which is what makes it feel like Jupyter.
      local CELL_MARKER = '^%s*#%s*%%%%'

      local function marker_lines()
        local out = {}
        for i, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
          if l:match(CELL_MARKER) then
            out[#out + 1] = i
          end
        end
        return out
      end

      -- Inclusive 1-indexed bounds of the cell holding the cursor, with the
      -- `# %%` line itself and any trailing blank lines trimmed off. A buffer
      -- with no markers is treated as one big cell.
      local function cell_bounds()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local n = #lines
        local cur = vim.api.nvim_win_get_cursor(0)[1]

        local first = cur
        while first > 1 and not lines[first]:match(CELL_MARKER) do
          first = first - 1
        end
        if lines[first] and lines[first]:match(CELL_MARKER) then
          first = first + 1
        end

        local last = cur
        while last < n and not lines[last + 1]:match(CELL_MARKER) do
          last = last + 1
        end
        while last >= first and lines[last]:match '^%s*$' do
          last = last - 1
        end

        return first, last
      end

      local function goto_cell(dir)
        local markers = marker_lines()
        if #markers == 0 then
          return false
        end
        local cur = vim.api.nvim_win_get_cursor(0)[1]

        -- Index of the marker opening the cell the cursor sits in, then step
        -- one cell either way from *that*. Comparing raw line numbers against
        -- the cursor instead makes a backward jump from mid-cell land on the
        -- current cell's own marker, which reads as "nothing happened".
        local here = 0
        for i, m in ipairs(markers) do
          if m <= cur then
            here = i
          else
            break
          end
        end

        local target = markers[here + dir]
        if not target then
          return false
        end
        local n = vim.api.nvim_buf_line_count(0)
        vim.api.nvim_win_set_cursor(0, { math.min(target + 1, n), 0 })
        vim.cmd 'normal! zz'
        return true
      end

      local function run_cell(advance)
        return function()
          if not molten_ready() then
            return
          end
          local first, last = cell_bounds()
          if first > last then
            vim.notify('Cell is empty', vim.log.levels.WARN, { title = 'molten-nvim' })
            return
          end
          vim.fn.MoltenEvaluateRange(first, last)
          if advance then
            goto_cell(1)
          end
        end
      end

      local molten_keymaps = {
        {
          '<localleader>jc',
          run_cell(false),
          desc = '[J]upyter run [C]ell',
          mode = 'n',
        },
        {
          '<localleader>jr',
          run_cell(true),
          desc = '[J]upyter [R]un cell and advance',
          mode = 'n',
        },
        {
          '<localleader>jn',
          function()
            goto_cell(1)
          end,
          desc = '[J]upyter [N]ext cell',
          mode = 'n',
        },
        {
          '<localleader>jp',
          function()
            goto_cell(-1)
          end,
          desc = '[J]upyter [P]revious cell',
          mode = 'n',
        },
        {
          '<localleader>jl',
          molten_cmd 'MoltenEvaluateLine',
          desc = '[J]upyter evaluate [L]ine',
          mode = 'n',
        },
        {
          -- NOTE: this is an *operator* — molten sets 'operatorfunc' and feeds
          -- g@, so it does nothing until you add a motion. <leader>jeip for
          -- the surrounding paragraph, <leader>jeG to end of file. Pressing
          -- <leader>je on its own looking dead is expected, not a bug.
          '<localleader>je',
          molten_cmd 'MoltenEvaluateOperator',
          desc = '[J]upyter [E]valuate (operator — needs a motion)',
          mode = 'n',
        },
        {
          '<localleader>je',
          molten_cmd('MoltenEvaluateVisual', { visual = true }),
          desc = '[J]upyter [E]valuate visual',
          mode = 'v',
        },
        {
          '<localleader>ja',
          function()
            -- Whole buffer. Uses MoltenEvaluateRange rather than
            -- ggVG + MoltenEvaluateVisual: no visual mode means nothing can
            -- strand the buffer in V-LINE when the evaluation fails.
            -- NOTE: molten registers this one with @pynvim.function, not
            -- @pynvim.command — ":MoltenEvaluateRange 1 30" is E492. It has
            -- to be *called*, with 1-indexed inclusive line numbers.
            if not molten_ready() then
              return
            end
            vim.fn.MoltenEvaluateRange(1, vim.api.nvim_buf_line_count(0))
          end,
          desc = '[J]upyter run [A]ll cells',
          mode = 'n',
        },
        {
          '<localleader>jR',
          molten_cmd 'MoltenReevaluateCell',
          desc = '[J]upyter [R]e-evaluate last cell',
          mode = 'n',
        },
        {
          '<localleader>jx',
          molten_cmd 'MoltenInterrupt',
          desc = '[J]upyter interrupt e[X]ecution',
          mode = 'n',
        },
        {
          '<localleader>jk',
          molten_cmd 'MoltenRestart!',
          desc = '[J]upyter restart [K]ernel (clears outputs)',
          mode = 'n',
        },
        {
          '<localleader>jh',
          molten_cmd 'MoltenHideOutput',
          desc = '[J]upyter [H]ide output',
          mode = 'n',
        },
        {
          '<localleader>jd',
          molten_cmd 'MoltenDelete',
          desc = '[J]upyter [D]elete cell',
          mode = 'n',
        },
        {
          '<localleader>jo',
          molten_cmd 'MoltenShowOutput',
          desc = '[J]upyter show [O]utput',
          mode = 'n',
        },
      }

      for _, map in ipairs(molten_keymaps) do
        vim.keymap.set(map.mode, map[1], map[2], { noremap = true, silent = true, desc = map.desc })
      end

      -- Which kernel to auto-attach, most specific first. The bare "python3"
      -- kernelspec ships inside the Nix python3 host env (see neovim.nix) and
      -- deliberately carries only ipykernel — no pandas, no numpy, nothing
      -- project-specific. Register a per-project kernel from its venv:
      --   uv venv && uv pip install ipykernel <your deps>
      --   .venv/bin/python -m ipykernel install --user --name <name>
      -- then add <name> here (or set vim.g.molten_preferred_kernels) so
      -- notebooks attach to the env that actually has your libraries.
      vim.g.molten_preferred_kernels = vim.g.molten_preferred_kernels or { 'pythonlib', 'python3' }

      -- First preferred kernel that is actually installed. jupyter_client
      -- looks in these three roots; checking the directory directly avoids
      -- shelling out to `jupyter kernelspec list` on every buffer read.
      local function pick_kernel()
        local roots = {
          vim.fn.expand '~/.local/share/jupyter/kernels',
          '/usr/local/share/jupyter/kernels',
          '/usr/share/jupyter/kernels',
        }
        for _, name in ipairs(vim.g.molten_preferred_kernels) do
          for _, root in ipairs(roots) do
            if vim.fn.isdirectory(root .. '/' .. name) == 1 then
              return name
            end
          end
        end
        -- Nothing matched on disk; the host env's built-in spec is still
        -- there, so fall back to it rather than popping a picker.
        return 'python3'
      end

      -- Initialize molten for Python buffers.
      -- Keyed on FileType, not BufRead: jupytext.nvim opens notebooks with a
      -- BufReadCmd, and defining one suppresses BufRead entirely — so a
      -- "*.ipynb" BufRead autocmd would simply never fire. By the time
      -- jupytext has converted the buffer it sets ft=python, which catches
      -- both real .py files and notebooks through one pattern.
      -- Guarded three ways:
      --  * :MoltenInit only exists once the remote-plugin manifest has been
      --    generated (:UpdateRemotePlugins) against a python3 host that has
      --    pynvim — otherwise every Python buffer throws
      --    "E492: Not an editor command: MoltenInit" on read.
      --  * the kernel is named explicitly, so this doesn't pop a kernel
      --    picker on every single Python buffer you open.
      --  * buffers that already have a kernel attached are skipped; a second
      --    :MoltenInit on one errors out.
      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('MoltenInit', { clear = true }),
        pattern = { 'python' },
        callback = function()
          if vim.fn.exists ':MoltenInit' ~= 2 then
            return
          end
          -- Skip buffers that already have a kernel; a second :MoltenInit on
          -- one errors. pcall because exists('*MoltenStatusLineKernels')
          -- reports 0 for lazily-defined rplugin functions even when the call
          -- works, which would make this check a no-op.
          local ok, kernels = pcall(vim.fn.MoltenStatusLineKernels, true)
          if ok and kernels ~= '' then
            return
          end
          vim.cmd('MoltenInit ' .. pick_kernel())
        end,
      })
    end,
  },

  -- image.nvim - Display images inline
  {
    '3rd/image.nvim',
    lazy = false,
    enabled = true,
    -- Skip image.nvim's luarocks build step: it only builds the optional
    -- `magick_rock` FFI processor, which needs a global Lua 5.1 + luarocks
    -- setup we don't have. We use the default `magick_cli` processor
    -- instead, which just shells out to `imagemagick`'s `magick` binary
    -- (already in PATH via home/viscous.nix's environment.systemPackages).
    -- Without this, every `:Lazy sync` prints a scary but harmless
    -- "Could not find Lua 5.1" build failure.
    build = false,
    config = function()
      require('image').setup {
        backend = 'kitty',
        integrations = {
          markdown = {
            enabled = true,
            clear_in_insert_mode = false,
            download_remote_images = true,
            only_render_image_at_cursor = false,
            filetypes = { 'markdown', 'vimwiki', 'ipynb' },
          },
          neorg = {
            enabled = true,
            filetypes = { 'norg' },
          },
          typst = {
            enabled = true,
            filetypes = { 'typst' },
          },
          html = {
            enabled = false,
          },
          css = {
            enabled = false,
          },
        },
        -- no hard cell caps; let images scale to the window (aspect ratio is always preserved)
        max_width_window_percentage = 100,
        max_height_window_percentage = 100,
        window_overlap_clear_enabled = false,
        window_overlap_clear_ft_ignore = { 'cmp_menu', 'scrollview', 'scrollview_sign' },
        editor_only_render_when_focused = true,
        tmux_show_only_in_active_window = true,
        hijack_file_patterns = { '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.avif', '*.svg' },
      }
    end,
  },

  -- nvim-cmp notebook-specific completion
  {
    'L3MON4D3/LuaSnip',
    version = 'v2.*',
    build = 'make install',
    lazy = true,
  },

  -- leetcode.nvim - solve LeetCode inside Neovim (dashboard, run/submit, image diagrams)
  {
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
  },
}