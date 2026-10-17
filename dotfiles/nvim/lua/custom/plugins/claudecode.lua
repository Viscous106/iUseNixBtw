-- Claude Code integration (replaces GitHub Copilot / CopilotChat)
return {
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
}
