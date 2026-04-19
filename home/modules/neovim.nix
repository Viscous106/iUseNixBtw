{ config, pkgs, ... }:

{
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    viAlias       = true;
    vimAlias      = true;
    withNodeJs    = true;
    withPython3   = true;

    extraPackages = with pkgs; [
      # Runtimes needed by LSPs
      nodejs_20
      python3
      # Fuzzy search (Telescope dependency)
      ripgrep
      fd
      git
      # LSP servers — managed by Nix so they're always available
      lua-language-server
      nil                                    # Nix LSP
      nixd                                   # Alternative Nix LSP (better)
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted  # html/css/json/eslint
      pyright                                # Python
      rust-analyzer
      gopls
      # Formatters / linters
      stylua
      shfmt
      nodePackages.prettier
      black
      isort
    ];
  };

  # ── init.lua — bootstraps lazy.nvim ───────────────────────────────────────
  xdg.configFile."nvim/init.lua".text = ''
    -- Bootstrap lazy.nvim
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not (vim.uv or vim.loop).fs_stat(lazypath) then
      vim.system({
        "git", "clone", "--filter=blob:none",
        "--branch=stable",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
      }):wait()
    end
    vim.opt.rtp:prepend(lazypath)

    require("config.options")
    require("config.keymaps")
    require("config.autocmds")
    require("lazy").setup({
      spec             = { { import = "plugins" } },
      change_detection = { notify = false },
      performance = {
        rtp = {
          disabled_plugins = {
            "gzip", "matchit", "matchparen", "netrwPlugin",
            "tarPlugin", "tohtml", "tutor", "zipPlugin",
          },
        },
      },
    })
  '';

  # ── Options ───────────────────────────────────────────────────────────────
  xdg.configFile."nvim/lua/config/options.lua".text = ''
    local opt = vim.opt

    -- Line numbers
    opt.number         = true
    opt.relativenumber = true

    -- Indent
    opt.expandtab   = true
    opt.tabstop     = 2
    opt.shiftwidth  = 2
    opt.smartindent = true

    -- Editor feel
    opt.wrap         = false
    opt.scrolloff    = 8
    opt.sidescrolloff = 8
    opt.cursorline   = true
    opt.signcolumn   = "yes"
    opt.termguicolors = true
    opt.showmode     = false       -- starship handles this

    -- Files
    opt.undofile = true
    opt.undodir  = vim.fn.stdpath("state") .. "/undo"
    opt.swapfile = false
    opt.backup   = false

    -- Clipboard (Wayland)
    opt.clipboard = "unnamedplus"

    -- Search
    opt.ignorecase = true
    opt.smartcase  = true
    opt.hlsearch   = false
    opt.incsearch  = true

    -- Split direction
    opt.splitright = true
    opt.splitbelow = true

    -- Completion
    opt.completeopt = { "menu", "menuone", "noselect" }

    -- Leader keys
    vim.g.mapleader      = " "
    vim.g.maplocalleader = ","
  '';

  # ── Keymaps ───────────────────────────────────────────────────────────────
  xdg.configFile."nvim/lua/config/keymaps.lua".text = ''
    local map = vim.keymap.set

    -- Better escape
    map("i", "jk", "<ESC>")
    map("i", "kj", "<ESC>")

    -- Save / Quit
    map("n", "<leader>w", "<cmd>w<cr>")
    map("n", "<leader>q", "<cmd>q<cr>")
    map("n", "<leader>Q", "<cmd>qa!<cr>")

    -- Window navigation
    map("n", "<C-h>", "<C-w>h")
    map("n", "<C-j>", "<C-w>j")
    map("n", "<C-k>", "<C-w>k")
    map("n", "<C-l>", "<C-w>l")

    -- Resize splits
    map("n", "<C-Up>",    "<cmd>resize +2<cr>")
    map("n", "<C-Down>",  "<cmd>resize -2<cr>")
    map("n", "<C-Left>",  "<cmd>vertical resize -2<cr>")
    map("n", "<C-Right>", "<cmd>vertical resize +2<cr>")

    -- Buffer navigation
    map("n", "<S-h>", "<cmd>bprevious<cr>")
    map("n", "<S-l>", "<cmd>bnext<cr>")
    map("n", "<leader>bd", "<cmd>bdelete<cr>")

    -- Move lines in visual mode
    map("v", "J", ":m '>+1<cr>gv=gv")
    map("v", "K", ":m '<-2<cr>gv=gv")

    -- Keep cursor centred while scrolling / searching
    map("n", "<C-d>", "<C-d>zz")
    map("n", "<C-u>", "<C-u>zz")
    map("n", "n", "nzzzv")
    map("n", "N", "Nzzzv")

    -- No yank on paste over selection
    map("v", "p", '"_dP')

    -- Clear search highlight
    map("n", "<Esc>", "<cmd>nohlsearch<cr>")

    -- Diagnostic navigation
    map("n", "[d", vim.diagnostic.goto_prev)
    map("n", "]d", vim.diagnostic.goto_next)
    map("n", "<leader>cd", vim.diagnostic.open_float)
  '';

  # ── Autocmds ──────────────────────────────────────────────────────────────
  xdg.configFile."nvim/lua/config/autocmds.lua".text = ''
    local augroup = vim.api.nvim_create_augroup
    local autocmd = vim.api.nvim_create_autocmd

    -- Highlight on yank
    autocmd("TextYankPost", {
      group    = augroup("highlight_yank", { clear = true }),
      callback = function() vim.highlight.on_yank() end,
    })

    -- Return to last cursor position
    autocmd("BufReadPost", {
      group = augroup("last_position", { clear = true }),
      callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
          pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
      end,
    })

    -- Auto-close nvim if NeoTree is last window
    autocmd("QuitPre", {
      group = augroup("auto_quit", { clear = true }),
      callback = function()
        local invalid_win = {}
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(w)
          if vim.bo[buf].filetype == "neo-tree" then
            table.insert(invalid_win, w)
          end
        end
        if #invalid_win == #vim.api.nvim_list_wins() - 1 then
          for _, w in ipairs(invalid_win) do vim.api.nvim_win_close(w, true) end
        end
      end,
    })
  '';

  # ── Plugins ───────────────────────────────────────────────────────────────
  xdg.configFile."nvim/lua/plugins/init.lua".text = ''
    return {
      -- ── Colorscheme ────────────────────────────────────────────────────
      {
        "catppuccin/nvim",
        name     = "catppuccin",
        priority = 1000,
        opts = { flavour = "mocha", transparent_background = true },
        config = function(_, opts)
          require("catppuccin").setup(opts)
          vim.cmd.colorscheme("catppuccin")
        end,
      },

      -- ── LSP ────────────────────────────────────────────────────────────
      {
        "neovim/nvim-lspconfig",
        dependencies = {
          "williamboman/mason.nvim",
          "williamboman/mason-lspconfig.nvim",
          "hrsh7th/nvim-cmp",
          "hrsh7th/cmp-nvim-lsp",
          "hrsh7th/cmp-buffer",
          "hrsh7th/cmp-path",
          "L3MON4D3/LuaSnip",
          "saadparwaiz1/cmp_luasnip",
          "rafamadriz/friendly-snippets",
          "j-hui/fidget.nvim",
        },
        config = function()
          require("fidget").setup()

          -- Completion
          local cmp     = require("cmp")
          local luasnip = require("luasnip")
          require("luasnip.loaders.from_vscode").lazy_load()

          cmp.setup({
            snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
            mapping = cmp.mapping.preset.insert({
              ["<C-n>"]   = cmp.mapping.select_next_item(),
              ["<C-p>"]   = cmp.mapping.select_prev_item(),
              ["<C-d>"]   = cmp.mapping.scroll_docs(-4),
              ["<C-f>"]   = cmp.mapping.scroll_docs(4),
              ["<C-Space>"] = cmp.mapping.complete(),
              ["<CR>"]    = cmp.mapping.confirm({ select = true }),
              ["<Tab>"]   = cmp.mapping(function(fallback)
                if cmp.visible() then cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
                else fallback() end
              end, { "i", "s" }),
            }),
            sources = {
              { name = "nvim_lsp" },
              { name = "luasnip" },
              { name = "buffer" },
              { name = "path" },
            },
          })

          -- LSP servers (Nix provides binaries; Mason handles extras)
          require("mason").setup()
          require("mason-lspconfig").setup({
            ensure_installed = { "lua_ls", "ts_ls", "pyright", "rust_analyzer" },
          })

          local caps = require("cmp_nvim_lsp").default_capabilities()
          local lsp  = require("lspconfig")

          local on_attach = function(_, buf)
            local opts = { buffer = buf }
            vim.keymap.set("n", "gd",         vim.lsp.buf.definition, opts)
            vim.keymap.set("n", "gD",         vim.lsp.buf.declaration, opts)
            vim.keymap.set("n", "gr",         vim.lsp.buf.references, opts)
            vim.keymap.set("n", "gi",         vim.lsp.buf.implementation, opts)
            vim.keymap.set("n", "K",          vim.lsp.buf.hover, opts)
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
            vim.keymap.set("n", "<leader>f",  function() vim.lsp.buf.format({ async = true }) end, opts)
          end

          local servers = { "lua_ls", "ts_ls", "pyright", "nil_ls", "nixd", "rust_analyzer", "gopls" }
          for _, s in ipairs(servers) do
            pcall(lsp[s].setup, { capabilities = caps, on_attach = on_attach })
          end
        end,
      },

      -- ── Treesitter ─────────────────────────────────────────────────────
      {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        opts = {
          ensure_installed = { "lua", "python", "typescript", "nix", "rust", "go", "bash", "json", "yaml", "toml", "markdown" },
          highlight        = { enable = true },
          indent           = { enable = true },
        },
        config = function(_, opts) require("nvim-treesitter.configs").setup(opts) end,
      },

      -- ── Telescope ──────────────────────────────────────────────────────
      {
        "nvim-telescope/telescope.nvim",
        dependencies = {
          "nvim-lua/plenary.nvim",
          { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        keys = {
          { "<leader>ff", "<cmd>Telescope find_files<cr>",                desc = "Find files" },
          { "<leader>fg", "<cmd>Telescope live_grep<cr>",                 desc = "Live grep" },
          { "<leader>fb", "<cmd>Telescope buffers<cr>",                   desc = "Buffers" },
          { "<leader>fh", "<cmd>Telescope help_tags<cr>",                 desc = "Help" },
          { "<leader>fr", "<cmd>Telescope oldfiles<cr>",                  desc = "Recent files" },
          { "<leader>fc", "<cmd>Telescope colorscheme<cr>",               desc = "Colorschemes" },
          { "<leader>gs", "<cmd>Telescope git_status<cr>",                desc = "Git status" },
        },
        config = function()
          require("telescope").setup({
            defaults = {
              prompt_prefix  = " ",
              selection_caret = " ",
              file_ignore_patterns = { "node_modules", ".git/", ".direnv" },
              layout_config  = { horizontal = { preview_width = 0.55 } },
            },
          })
          require("telescope").load_extension("fzf")
        end,
      },

      -- ── File tree (NeoTree) ─────────────────────────────────────────────
      {
        "nvim-neo-tree/neo-tree.nvim",
        dependencies = {
          "nvim-lua/plenary.nvim",
          "nvim-tree/nvim-web-devicons",
          "MunifTanjim/nui.nvim",
        },
        keys = { { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "File Explorer" } },
        opts = {
          close_if_last_window = true,
          filesystem = {
            filtered_items = { visible = true, hide_dotfiles = false },
            follow_current_file = { enabled = true },
          },
        },
      },

      -- ── Git ────────────────────────────────────────────────────────────
      { "lewis6991/gitsigns.nvim",  opts = {} },
      { "kdheepak/lazygit.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = { { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" } },
      },

      -- ── UI ─────────────────────────────────────────────────────────────
      { "nvim-lualine/lualine.nvim",
        opts = { theme = "catppuccin", globalstatus = true },
      },
      { "akinsho/bufferline.nvim",
        dependencies = "nvim-tree/nvim-web-devicons",
        opts = { options = { separator_style = "slant" } },
      },
      { "folke/noice.nvim",
        dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" },
        opts = { lsp = { override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        }}},
      },
      { "folke/which-key.nvim", event = "VeryLazy", opts = {} },
      { "lukas-reineke/indent-blankline.nvim",
        main = "ibl", opts = { indent = { char = "│" } },
      },
      { "NvChad/nvim-colorizer.lua", opts = {} },

      -- ── Editing ────────────────────────────────────────────────────────
      { "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts  = { check_ts = true },
      },
      { "kylechui/nvim-surround",   event = "VeryLazy", opts = {} },
      { "numToStr/Comment.nvim",    opts = {} },
      { "stevearc/conform.nvim",
        opts = {
          formatters_by_ft = {
            lua        = { "stylua" },
            python     = { "isort", "black" },
            javascript = { "prettier" },
            typescript = { "prettier" },
            nix        = { "nixfmt" },
            sh         = { "shfmt" },
          },
          format_on_save = { timeout_ms = 500, lsp_fallback = true },
        },
      },
    }
  '';
}
