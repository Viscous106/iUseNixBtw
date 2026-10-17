-- live-server
return {
  'barrett-ruth/live-server.nvim',
  build = 'npm install -g live-server',
  cmd = { 'LiveServerStart', 'LiveServerStop', 'LiveServerToggle' },
  keys = {
    { '<leader>ls', '<cmd>LiveServerToggle<CR>', desc = '[L]ive [S]erver toggle' },
  },
  config = true,
}
