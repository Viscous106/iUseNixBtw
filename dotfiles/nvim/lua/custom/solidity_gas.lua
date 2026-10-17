-- Remix-style inline gas estimates for Solidity, from `forge inspect`.
-- Numbers come from solc's static estimator (same source as Remix), so
-- anything it can't bound — loops, external calls, checked arithmetic —
-- shows as "infinite".
local M = {}

local ns = vim.api.nvim_create_namespace 'solidity_gas'
local enabled = true
local buffers = {} -- [bufnr] = { running = bool, pending = bool }

local function set_highlight()
  vim.api.nvim_set_hl(0, 'SolidityGas', { link = 'Comment', default = true })
end
set_highlight()
vim.api.nvim_create_autocmd('ColorScheme', { callback = set_highlight })

local function format_gas(value)
  if value == nil or value == vim.NIL then
    return nil
  end
  if value == 'infinite' then
    return 'infinite'
  end
  local digits = tostring(value):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
  return digits .. ' gas'
end

-- ABI input -> canonical type, expanding tuples (structs) recursively.
local function canonical_type(input)
  local t = input.type
  if t:sub(1, 5) == 'tuple' then
    local parts = {}
    for _, component in ipairs(input.components) do
      table.insert(parts, canonical_type(component))
    end
    return '(' .. table.concat(parts, ',') .. ')' .. t:sub(6)
  end
  return t
end

local function abi_signature(entry)
  local types = {}
  for _, input in ipairs(entry.inputs) do
    table.insert(types, canonical_type(input))
  end
  return entry.name .. '(' .. table.concat(types, ',') .. ')'
end

-- Arity of a signature like "f(uint256,(uint256,uint256))", counting only top-level commas.
local function signature_arity(sig)
  local args = sig:match '^[^(]*%((.*)%)$'
  if not args or args == '' then
    return 0
  end
  local depth, count = 0, 1
  for ch in args:gmatch '.' do
    if ch == '(' then
      depth = depth + 1
    elseif ch == ')' then
      depth = depth - 1
    elseif ch == ',' and depth == 0 then
      count = count + 1
    end
  end
  return count
end

local function node_text(node, buf)
  return vim.treesitter.get_node_text(node, buf)
end

local function child_of_type(node, type)
  for child in node:iter_children() do
    if child:type() == type then
      return child
    end
  end
end

-- Top-level contracts/libraries that have bytecode (interfaces and abstract contracts don't).
local function deployable_contracts(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'solidity')
  if not ok or not parser then
    return {}
  end
  local contracts = {}
  for node in parser:parse()[1]:root():iter_children() do
    local t = node:type()
    if (t == 'contract_declaration' and not child_of_type(node, 'abstract')) or t == 'library_declaration' then
      table.insert(contracts, node)
    end
  end
  return contracts
end

-- One contract's declarations -> { [row] = label }.
local function contract_labels(buf, contract, abi, gas)
  local labels = {}
  local abi_functions = {}
  for _, entry in ipairs(abi) do
    if entry.type == 'function' then
      table.insert(abi_functions, entry)
    end
  end

  local function external_by_name(name, params)
    local candidates = vim.tbl_filter(function(e)
      return e.name == name and (params == nil or #e.inputs == #params)
    end, abi_functions)
    if params and #candidates > 1 then
      candidates = vim.tbl_filter(function(e)
        for i, input in ipairs(e.inputs) do
          if input.name ~= params[i] then
            return false
          end
        end
        return true
      end, candidates)
    end
    if #candidates == 1 then
      return format_gas(gas.external[abi_signature(candidates[1])])
    end
  end

  local function internal_by_name(name, arity)
    local found
    for sig, value in pairs(gas.internal or {}) do
      if sig:match '^[^(]*' == name and signature_arity(sig) == arity then
        if found then
          return nil
        end
        found = value
      end
    end
    return format_gas(found)
  end

  local has_constructor = false
  local body = contract:field('body')[1]
  for decl in body:iter_children() do
    local t = decl:type()
    local row = decl:start()
    if t == 'function_definition' then
      local name = node_text(decl:field('name')[1], buf)
      local params, visibility = {}, nil
      for child in decl:iter_children() do
        if child:type() == 'parameter' then
          local pname = child:field('name')[1]
          table.insert(params, pname and node_text(pname, buf) or '')
        elseif child:type() == 'visibility' then
          visibility = node_text(child, buf)
        end
      end
      if visibility == 'public' or visibility == 'external' then
        labels[row] = external_by_name(name, params)
      else
        labels[row] = internal_by_name(name, #params)
      end
    elseif t == 'state_variable_declaration' then
      local visibility = decl:field('visibility')[1]
      if visibility and node_text(visibility, buf) == 'public' then
        labels[row] = external_by_name(node_text(decl:field('name')[1], buf), nil)
      end
    elseif t == 'constructor_definition' then
      has_constructor = true
      local cost = format_gas(gas.creation and gas.creation.totalCost)
      labels[row] = cost and ('deploy ' .. cost)
    elseif t == 'fallback_receive_definition' then
      labels[row] = format_gas(gas.external[''])
    end
  end

  if not has_constructor then
    local cost = format_gas(gas.creation and gas.creation.totalCost)
    labels[contract:start()] = cost and ('deploy ' .. cost)
  end
  return labels
end

local function render(buf, results)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if enabled then
    for _, contract in ipairs(deployable_contracts(buf)) do
      local result = results[node_text(contract:field('name')[1], buf)]
      if result then
        for row, label in pairs(contract_labels(buf, contract, result.abi, result.gas)) do
          vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
            -- U+F0298 is nf-md-gas_station
            virt_text = { { (vim.g.have_nerd_font and '\u{F0298} ' or '⛽ ') .. label, 'SolidityGas' } },
            virt_text_pos = 'eol',
          })
        end
      end
    end
  end
  vim.api.nvim_exec_autocmds('User', { pattern = 'SolidityGasUpdated', data = { buf = buf } })
end

-- vim.system's callback runs in a fast-event context where buffer APIs are
-- forbidden, so hop back to the main loop before touching anything.
local function forge_inspect(root, id, field, callback)
  vim.system({ 'forge', 'inspect', id, field, '--json' }, { cwd = root, text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        return callback(nil)
      end
      local ok, decoded = pcall(vim.json.decode, obj.stdout)
      callback((ok and type(decoded) == 'table') and decoded or nil)
    end)
  end)
end

-- One refresh per buffer at a time: forge processes sharing cache/ and out/
-- must not overlap, so saves during a run just queue one more pass.
function M.refresh(buf)
  local state = buffers[buf]
  if not state or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if state.running then
    state.pending = true
    return
  end

  local root = vim.fs.root(buf, 'foundry.toml')
  local relpath = root and vim.fs.relpath(root, vim.api.nvim_buf_get_name(buf))
  if not relpath then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    return
  end

  local names = {}
  for _, contract in ipairs(deployable_contracts(buf)) do
    table.insert(names, node_text(contract:field('name')[1], buf))
  end

  state.running = true
  local results, i = {}, 0
  local function step()
    i = i + 1
    local name = names[i]
    if not name then
      state.running = false
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if state.pending then
        state.pending = false
        return M.refresh(buf)
      end
      return render(buf, results)
    end
    local id = relpath .. ':' .. name
    forge_inspect(root, id, 'abi', function(abi)
      if not abi then
        return step()
      end
      forge_inspect(root, id, 'gasEstimates', function(gas)
        if gas then
          results[name] = { abi = abi, gas = gas }
        end
        step()
      end)
    end)
  end
  step()
end

function M.toggle()
  enabled = not enabled
  for buf in pairs(buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      if enabled then
        M.refresh(buf)
      else
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      end
    end
  end
end

function M.attach(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if vim.fn.executable 'forge' ~= 1 then
    return
  end
  -- FileType fires again on :e / external reloads; just redraw then.
  if buffers[buf] then
    if enabled then
      M.refresh(buf)
    end
    return
  end
  buffers[buf] = { running = false, pending = false }

  vim.api.nvim_create_autocmd('BufWritePost', {
    buffer = buf,
    callback = function()
      if enabled then
        M.refresh(buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    callback = function()
      buffers[buf] = nil
    end,
  })
  vim.keymap.set('n', '<leader>tg', M.toggle, { buffer = buf, desc = '[T]oggle Solidity [G]as estimates' })

  if enabled then
    M.refresh(buf)
  end
end

return M
