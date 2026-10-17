-- Molten.nvim - Jupyter notebook support
return {
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
}
