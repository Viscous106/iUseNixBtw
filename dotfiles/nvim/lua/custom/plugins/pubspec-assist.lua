-- pubspec-assist.nvim - manage pubspec.yaml dependencies
return {
  'akinsho/pubspec-assist.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  ft = { 'yaml' },
  event = 'BufRead pubspec.yaml',
  config = true,
}
