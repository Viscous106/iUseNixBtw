-- Jupyter notebook editing: .ipynb <-> percent-format Python.

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
    -- ft=python enables LSP, treesitter and molten auto-attach (custom/plugins/molten.lua).
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
