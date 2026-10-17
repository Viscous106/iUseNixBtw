-- Neovim config (fork of kickstart.nvim). Extra plugins: lua/custom/plugins/.

-- Leader must be set before plugins load.
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.netrw_browsex_viewer = 'zen-beta'

vim.fn.serverstart()

vim.g.have_nerd_font = true

-- Disable optional remote-host providers we don't use (silences :checkhealth
-- warnings for Node/Perl/Ruby). Clipboard is handled natively via wl-copy.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- python3 provider for molten-nvim (needs pynvim). Built in home/dev/neovim.nix as
-- `nvim-python3-host`; withPython3 is off there since it would generate a competing init.lua.
local python3_host = vim.fn.exepath 'nvim-python3-host'
if python3_host ~= '' then
  vim.g.python3_host_prog = python3_host
else
  vim.g.loaded_python3_provider = 0
end

-- [[ Options ]]
vim.o.number = true
vim.o.mouse = 'a'
vim.o.showmode = false -- shown in the statusline

-- System clipboard via wl-clipboard; scheduled since it can slow startup.
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
  vim.env.WAYLAND_DISPLAY = vim.env.WAYLAND_DISPLAY or 'wayland-1'
  vim.env.XDG_RUNTIME_DIR = vim.env.XDG_RUNTIME_DIR or '/run/user/1000'
  vim.g.clipboard = {
    name = 'wl-clipboard',
    copy = {
      ['+'] = { 'wl-copy' },
      ['*'] = { 'wl-copy', '--primary' },
    },
    paste = {
      ['+'] = { 'wl-paste', '--no-newline' },
      ['*'] = { 'wl-paste', '--no-newline', '--primary' },
    },
    cache_enabled = 1,
  }
end)

vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.scrolloff = 10
vim.o.confirm = true -- prompt to save instead of failing on :q

-- [[ Basic Keymaps ]]
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>cl', '<cmd>messages clear<CR>', { desc = '[C]lear messages' })

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- splits
vim.keymap.set('n', '<leader>\\', '<cmd>vsplit<CR>', { desc = 'Split window vertically' })
vim.keymap.set('n', '<leader>-', '<cmd>split<CR>', { desc = 'Split window horizontally' })

vim.keymap.set('n', '<localleader>jv', function()
  local file = vim.fn.expand '%:p'
  if vim.fn.expand '%:e' == 'ipynb' then
    vim.cmd('terminal view-notebook ' .. file)
  else
    vim.notify('Only works on .ipynb files', vim.log.levels.WARN)
  end
end, { desc = '[J]upyter [V]iew notebook (interactive)' })


vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- CTRL+hjkl window navigation comes from vim-tmux-navigator.

-- window resizing
vim.keymap.set('n', '<C-Up>', ':resize +2<CR>', { desc = 'Increase window height', silent = true })
vim.keymap.set('n', '<C-Down>', ':resize -2<CR>', { desc = 'Decrease window height', silent = true })
vim.keymap.set('n', '<C-Left>', ':vertical resize -2<CR>', { desc = 'Decrease window width', silent = true })
vim.keymap.set('n', '<C-Right>', ':vertical resize +2<CR>', { desc = 'Increase window width', silent = true })

vim.keymap.set('n', '<M-k>', ':resize +5<CR>', { desc = 'Increase window height (fast)', silent = true })
vim.keymap.set('n', '<M-j>', ':resize -5<CR>', { desc = 'Decrease window height (fast)', silent = true })
vim.keymap.set('n', '<M-h>', ':vertical resize -5<CR>', { desc = 'Decrease window width (fast)', silent = true })
vim.keymap.set('n', '<M-l>', ':vertical resize +5<CR>', { desc = 'Increase window width (fast)', silent = true })

-- Terminal/browser-like word navigation and deletion in insert mode
vim.keymap.set('i', '<M-BS>', '<C-w>', { desc = 'Delete word backward' })
vim.keymap.set('i', '<C-Left>', '<C-o>b', { desc = 'Move word backward' })
vim.keymap.set('i', '<C-Right>', '<C-o>w', { desc = 'Move word forward' })

-- [[ Basic Autocommands ]]
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- [[ lazy.nvim bootstrap ]]
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Plugins ]]
require('lazy').setup({
  'NMAC427/guess-indent.nvim', -- Detect tabstop and shiftwidth automatically

  { -- git signs in the gutter
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },

  { -- pending-keybind hints
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      delay = 0,
      icons = {
        mappings = vim.g.have_nerd_font,
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      -- key-chain group labels
      spec = {
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = '[H]arpoon' },
        { '<leader>g', group = '[G]it' },
        { '<leader>F', group = '[F]lutter' },
        { '<leader>L', group = '[L]eetCode' },
      },
    },
  },

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      require('telescope').setup {
        defaults = {
          file_ignore_patterns = {
            '%.git/',
            'node_modules/',
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>sa', function()
        builtin.find_files { no_ignore = true, hidden = true }
      end, { desc = '[S]earch [A]ll Files (including ignored)' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- LSP Plugins
  {
    -- Lua LSP types for the Neovim API
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Mason must be set up before its dependents.
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
      'saghen/blink.cmp',
    },
    config = function()
      -- Per-buffer LSP keymaps and highlights.
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          map('grr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

          map('gri', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')

          map('grd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

          -- Declaration, not definition (e.g. the C header).
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')

          map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')

          map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')

          -- supports_method changed signature in nvim 0.11
          ---@param client vim.lsp.Client
          ---@param method vim.lsp.protocol.Method
          ---@param bufnr? integer some lsp support methods only in specific files
          ---@return boolean
          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          -- Highlight references under the cursor on CursorHold; clear on move.
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- Inlay hints toggle, when the server supports them.
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      -- Advertise blink.cmp's extra completion capabilities to servers.
      local capabilities = require('blink.cmp').get_lsp_capabilities()

      -- Servers here are auto-installed by Mason; values override lspconfig defaults.
      local servers = {
        gopls = {},
        jdtls = {},
        ['typescript-language-server'] = {},
        -- Nomic Foundation's Solidity LSP: understands Foundry projects (foundry.toml),
        -- unlike the older solidity_ls.
        solidity_ls_nomicfoundation = {},

        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
            },
          },
        },
      }

      -- Servers above plus extra tools, installed via mason-tool-installer.
      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua', -- Used to format Lua code
        'codelldb',
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        ensure_installed = {}, -- installs go through mason-tool-installer
        automatic_installation = false,
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- No format-on-save for languages without a standard style.
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        solidity = { 'forge_fmt' },
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          -- jsregexp build for regex snippets; skipped without make.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
        },
        opts = {},
      },
      'folke/lazydev.nvim',
    },
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = {
        -- <CR> accepts when the menu is open, else newline; <S-CR> always inserts a newline.
        preset = 'enter',

        ['<S-CR>'] = { 'fallback' },
      },

      appearance = {
        nerd_font_variant = 'mono',
      },

      completion = {
        -- docs on <c-space>
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = {
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },

      snippets = { preset = 'luasnip' },

      -- Lua matcher: the Rust one downloads a prebuilt binary.
      fuzzy = { implementation = 'lua' },

      signature = { enabled = true },
    },
  },

  { -- colorscheme
    'folke/tokyonight.nvim',
    priority = 1000, -- load before other start plugins
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false },
        },
      }

      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- around/inside textobjects (va), yinq, ci')
      require('mini.ai').setup { n_lines = 500 }

      -- surroundings: saiw), sd', sr)'
      require('mini.surround').setup()
    end,
  },
  { -- Highlight, edit, and navigate code
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
  },

  -- Markdown plugins
  { 'preservim/vim-markdown', ft = 'markdown' },
  {
    'iamcco/markdown-preview.nvim',
    ft = 'markdown',
    build = 'cd app && yarn install --frozen-lockfile',
    config = function()
      vim.g.mkdp_filetypes = { 'markdown' }
      vim.g.mkdp_browser = 'zen-beta'
      vim.api.nvim_set_keymap('n', '<leader>md', '<Plug>MarkdownPreviewToggle', { noremap = true, silent = true })
    end,
  },

  require 'kickstart.plugins.debug',
  require 'kickstart.plugins.neo-tree',

  { import = 'custom.plugins' }, -- lua/custom/plugins/*.lua
}, {
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- ============================================================================
-- JUPYTER NOTEBOOK AUTOMATION
-- ============================================================================

vim.keymap.set('n', '<localleader>ji', '<cmd>NotebookInit<CR>', { desc = '[J]upyter [I]nit (.py → .ipynb)' })
vim.keymap.set('n', '<localleader>js', '<cmd>NotebookToScript<CR>', { desc = '[J]upyter to [S]cript (.ipynb → .py)' })

-- .ipynb editing via BufReadCmd/BufWriteCmd. Not jupytext.nvim: its sidecar foo.py
-- collides with a real foo.py next to foo.ipynb, which is exactly this workflow.

-- .py -> .ipynb: uses `# %%` markers if present, else one cell per blank-line block
-- (comment-only blocks become markdown). Keeps the existing notebook's kernel metadata.
local NB_PY_TO_IPYNB = [==[
import json, os, re, sys

src, dst, kernel = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(src).read()
marked = re.search(r"^\s*#\s*%%", text, re.M) is not None

def mkcell(kind, body):
    body = body.rstrip("\n")
    if not body.strip():
        return None
    lines = body.split("\n")
    source = [l + "\n" for l in lines[:-1]] + [lines[-1]]
    if kind == "markdown":
        return {"cell_type": "markdown", "metadata": {}, "source": source}
    return {"cell_type": "code", "execution_count": None,
            "metadata": {}, "outputs": [], "source": source}

cells = []
if marked:
    kind, buf = "code", []
    for line in text.splitlines(True):
        s = line.strip()
        if s.startswith("# %%"):
            c = mkcell(kind, "".join(buf))
            if c: cells.append(c)
            kind = "markdown" if "[markdown]" in s else "code"
            buf = []
        elif kind == "markdown" and s.startswith("#"):
            buf.append(s[1:].lstrip() + "\n")
        else:
            buf.append(line)
    c = mkcell(kind, "".join(buf))
    if c: cells.append(c)
else:
    for block in re.split(r"\n\s*\n", text):
        if not block.strip():
            continue
        lines = [l for l in block.split("\n") if l.strip()]
        if all(l.lstrip().startswith("#") for l in lines):
            body = "\n".join(l.lstrip()[1:].lstrip() for l in lines)
            c = mkcell("markdown", body)
        else:
            c = mkcell("code", block)
        if c: cells.append(c)

meta = {"kernelspec": {"display_name": kernel, "language": "python", "name": kernel},
        "language_info": {"name": "python"}}
if os.path.exists(dst):
    try:
        old = json.load(open(dst)).get("metadata")
        if old and old.get("kernelspec"):
            meta = old
    except (ValueError, OSError):
        pass

json.dump({"cells": cells, "metadata": meta, "nbformat": 4, "nbformat_minor": 4},
          open(dst, "w"), indent=1)
]==]

-- .ipynb -> .py: "percent" adds `# %%` headers for molten (buffer view);
-- "plain" is the <localleader>js export without markers.
local NB_IPYNB_TO_PY = [==[
import json, sys

src, dst, mode = sys.argv[1], sys.argv[2], sys.argv[3]
out = []
for cell in json.load(open(src)).get("cells", []):
    body = "".join(cell["source"]).rstrip("\n")
    if cell["cell_type"] == "markdown":
        if mode == "percent":
            out.append("# %% [markdown]")
        out += ["# " + l if l else "#" for l in body.split("\n")]
    else:
        if mode == "percent":
            out.append("# %%")
        out.append(body)
    out.append("")
open(dst, "w").write("\n".join(out).rstrip("\n") + "\n")
]==]

-- Same kernel molten auto-attaches to.
local function nb_kernel()
  return (vim.g.molten_preferred_kernels or { 'python3' })[1]
end

-- Synchronous on purpose: callers need the output file immediately. Returns ok, output.
local function nb_run(script, args)
  local cmd = vim.list_extend({ 'python3', '-c', script }, args)
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify('Notebook conversion failed:\n' .. out, vim.log.levels.ERROR, { title = 'notebook' })
    return false, out
  end
  return true, out
end

local nb_group = vim.api.nvim_create_augroup('NotebookIpynb', { clear = true })

-- Read a notebook into the buffer as percent-format Python.
vim.api.nvim_create_autocmd('BufReadCmd', {
  group = nb_group,
  pattern = '*.ipynb',
  callback = function(ev)
    local tmp = vim.fn.tempname() .. '.py'
    if not nb_run(NB_IPYNB_TO_PY, { ev.match, tmp, 'percent' }) then
      return
    end
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.readfile(tmp))
    vim.fn.delete(tmp)
    vim.bo.modified = false
    -- ft=python enables LSP, treesitter and molten auto-attach (custom/plugins/init.lua).
    vim.cmd 'setlocal filetype=python'
  end,
})

-- Write the buffer back out as a notebook.
vim.api.nvim_create_autocmd('BufWriteCmd', {
  group = nb_group,
  pattern = '*.ipynb',
  callback = function(ev)
    local tmp = vim.fn.tempname() .. '.py'
    vim.fn.writefile(vim.api.nvim_buf_get_lines(0, 0, -1, false), tmp)
    local ok = nb_run(NB_PY_TO_IPYNB, { tmp, ev.match, nb_kernel() })
    vim.fn.delete(tmp)
    if not ok then
      return
    end
    vim.bo.modified = false
    -- Save molten's cell outputs into the notebook too.
    if vim.fn.exists ':MoltenExportOutput' == 2 then
      pcall(vim.cmd, 'MoltenExportOutput!')
    end
    vim.api.nvim_exec_autocmds('BufWritePost', { pattern = ev.match })
  end,
})

-- Convert the current .py to .ipynb and open it
vim.api.nvim_create_user_command('NotebookInit', function()
  local file = vim.fn.expand '%:p'
  if vim.fn.expand '%:e' ~= 'py' then
    vim.notify('Only works on .py files', vim.log.levels.WARN)
    return
  end
  if vim.bo.modified then
    vim.cmd 'write'
  end
  local ipynb = file:gsub('%.py$', '.ipynb')
  if nb_run(NB_PY_TO_IPYNB, { file, ipynb, nb_kernel() }) then
    vim.cmd('edit ' .. vim.fn.fnameescape(ipynb))
    vim.notify('Opened ' .. vim.fn.fnamemodify(ipynb, ':t'), vim.log.levels.INFO, { title = 'notebook' })
  end
end, {})

-- Convert the current .ipynb back to plain .py
vim.api.nvim_create_user_command('NotebookToScript', function()
  local file = vim.fn.expand '%:p'
  if vim.fn.expand '%:e' ~= 'ipynb' then
    vim.notify('Only works on .ipynb files', vim.log.levels.WARN)
    return
  end
  local py_file = file:gsub('%.ipynb$', '.py')
  if nb_run(NB_IPYNB_TO_PY, { file, py_file, 'plain' }) then
    vim.cmd('edit ' .. vim.fn.fnameescape(py_file))
    vim.notify('Exported ' .. vim.fn.fnamemodify(py_file, ':t'), vim.log.levels.INFO, { title = 'notebook' })
  end
end, {})

-- vim: ts=2 sts=2 sw=2 et
