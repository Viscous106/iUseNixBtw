-- Auto-close/rename HTML & JSX tags: typing `<div>` inserts `</div>`, and
-- renaming an opening tag renames its closing tag. Treesitter-driven, so the
-- parser for the filetype has to be installed (see `ensure_installed` in init.lua).
return {
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
}
