local module_cache = require('VeriSuite.core.module_cache')
local autoinst = require('VeriSuite.core.autoinst')

local defaults = {
  min_keyword_length = 1,
  priority = 40,
}

local M = {}
M.defaults = defaults

local function is_verilog_buf()
  local ft = vim.bo.filetype
  return ft == 'verilog' or ft == 'systemverilog' or ft == 'sv'
end

local function ensure_cache()
  if module_cache.cache.is_loaded or module_cache.cache.loading then
    return
  end
  module_cache.load_project()
end

local function wait_for_cache(on_ready, retries)
  retries = retries or 50 -- ~5s max with 100ms interval
  if module_cache.cache.is_loaded then
    on_ready()
    return
  end
  if retries <= 0 then
    vim.notify('VeriSuite cache not ready for completion', vim.log.levels.WARN)
    on_ready({})
    return
  end
  vim.defer_fn(function()
    wait_for_cache(on_ready, retries - 1)
  end, 100)
end

local function detect_instance_module(context)
  local cursor_row = context.cursor[1] - 1
  local cursor_col = context.cursor[2]
  local start_row = math.max(0, cursor_row - 6)
  local lines = vim.api.nvim_buf_get_lines(context.bufnr, start_row, cursor_row + 1, false)

  for i = #lines, 1, -1 do
    local line = lines[i]
    if i == #lines then
      line = string.sub(line, 1, cursor_col + 1)
    end
    local name = line:match('([%w_]+)%s+[%w_]+%s*#?%s*%(')
    if name then
      return name
    end
  end
  return nil
end

local function port_label(port)
  if port.width then
    return string.format('%s [%s]', port.name, port.width)
  end
  return port.name
end

local function port_insert_text(port)
  return string.format('.%s(%s)', port.name, port.name)
end

local function port_detail(module_name, port)
  local dir = port.direction or '?'
  local width = port.width and ('[' .. port.width .. ']') or ''
  return string.format('%s %s%s in %s', dir, port.name, width, module_name)
end

local function module_detail(module)
  local file = module.file and vim.fn.fnamemodify(module.file, ':t') or ''
  local ports = module.ports and #module.ports or 0
  return string.format('%s (%d ports)', file, ports)
end

local function module_instantiation_text(module)
  local lines = autoinst.auto_inst(module.name, module.parameters, module.ports)
  return table.concat(lines, '\n')
end

local function build_module_items()
  ensure_cache()
  local items = {}
  for _, name in ipairs(module_cache.get_module_names()) do
    local info = module_cache.get_module_info(name)
    if info and info.ports and #info.ports > 0 then
      local insert = module_instantiation_text(info)
      table.insert(items, {
        label = name,
        detail = module_detail(info),
        documentation = {
          kind = vim.lsp.protocol.MarkupKind.Markdown,
          value = 'Insert instantiation for `' .. name .. '`',
        },
        kind = vim.lsp.protocol.CompletionItemKind.Class,
        insertText = insert,
        insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      })
    end
  end
  return items
end

local function build_port_items(module_name)
  ensure_cache()
  local module_info = module_cache.get_module_info(module_name)
  if not module_info or not module_info.ports then
    return {}
  end

  local items = {}
  for _, port in ipairs(module_info.ports) do
    table.insert(items, {
      label = port_label(port),
      insertText = port_insert_text(port),
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
      detail = port_detail(module_name, port),
      kind = vim.lsp.protocol.CompletionItemKind.Field,
    })
  end
  return items
end

--- blink.cmp source constructor
--- @param opts table
--- @return table
function M.new(opts)
  opts = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
  return setmetatable({ opts = opts }, { __index = M })
end

function M:enabled()
  return is_verilog_buf()
end

-- 注册 blink.cmp provider 配置（需要在 blink.cmp.setup 之前调用）
function M.configure(opts)
  opts = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
  local ok, blink_config = pcall(require, 'blink.cmp.config')
  if not ok then
    vim.notify('blink.cmp not found for VeriSuite source', vim.log.levels.WARN)
    return
  end

  blink_config.sources.providers = blink_config.sources.providers or {}
  blink_config.sources.default = blink_config.sources.default or {}
  blink_config.sources.per_filetype = blink_config.sources.per_filetype or {}

  if not blink_config.sources.providers.verisuite then
    blink_config.sources.providers.verisuite = {
      module = 'VeriSuite.integrations.blink',
      name = 'VeriSuite',
      opts = opts,
      min_keyword_length = opts.min_keyword_length,
      score_offset = opts.priority,
      enabled = function()
        return is_verilog_buf()
      end,
    }
  end

  local function ensure(list, value)
    for _, v in ipairs(list) do
      if v == value then
        return
      end
    end
    table.insert(list, value)
  end

  ensure(blink_config.sources.default, 'verisuite')
  for _, ft in ipairs({ 'verilog', 'systemverilog', 'sv' }) do
    blink_config.sources.per_filetype[ft] = blink_config.sources.per_filetype[ft] or { inherit_defaults = true }
    ensure(blink_config.sources.per_filetype[ft], 'verisuite')
  end
end

function M:get_trigger_characters()
  return { '.', '(', ',' }
end

function M:get_completions(context, callback)
  if not is_verilog_buf() then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return function() end
  end

  ensure_cache()

  local function produce_items()
    local target_module = detect_instance_module(context)
    local items

    if target_module then
      items = build_port_items(target_module)
      if #items == 0 then
        items = build_module_items()
      end
    else
      items = build_module_items()
    end

    callback({
      items = items,
      is_incomplete_forward = false,
      is_incomplete_backward = false,
    })
  end

  if module_cache.cache.is_loaded then
    produce_items()
  else
    wait_for_cache(produce_items)
  end

  return function() end
end

function M.show_completion()
  local ok, blink_cmp = pcall(require, 'blink.cmp')
  if not ok then
    vim.notify('blink.cmp not available', vim.log.levels.WARN)
    return
  end
  ensure_cache()
  blink_cmp.show({ providers = { 'verisuite' } })
end

function M.register_command()
  vim.api.nvim_create_user_command('VeriSuiteBlinkComplete', function()
    M.show_completion()
  end, { desc = 'Show VeriSuite blink completion' })
end

return M
