-- Alpha - startup dashboard
return {
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
}
