local M = {}

---@param module_name string
---@param params table
---@param ports table
---@return string[]
function M.auto_inst(module_name, params, ports)
  local lines = {}

  local module_name = module_name or 'unknown_module'
  local instance_name = 'u_' .. module_name

  if params and #params > 0 then
    table.insert(lines, string.format('%s #(', module_name))

    for i, param in ipairs(params) do
      local separator = (i == #params) and '' or ','
      local param_value = param.value or '0' -- 默认值
      table.insert(lines, string.format('  .%s(%s)%s', param.name, param_value, separator))
    end

    table.insert(lines, string.format(') %s (', instance_name))
  else
    table.insert(lines, string.format('%s %s (', module_name, instance_name))
  end

  if ports and #ports > 0 then
    for i, port in ipairs(ports) do
      local separator = (i == #ports) and '' or ','
      local wire_name = port.name
      table.insert(lines, string.format('  .%s(%s)%s', port.name, wire_name, separator))
    end
  end

  table.insert(lines, ');')

  return lines
end

-- 通过模块名自动生成实例化代码
---@param module_name string
---@param use_cache boolean? 是否使用缓存（默认true）
---@return string[]|nil 返回生成的代码行，失败返回nil
function M.auto_instance_by_name(module_name, use_cache)
  use_cache = use_cache ~= false -- 默认为true

  -- 尝试从缓存获取模块信息
  local module_info = nil
  if use_cache then
    local module_cache_ok, module_cache = pcall(require, 'VeriSuite.core.module_cache')
    if module_cache_ok then
      module_info = module_cache.get_module_info(module_name)
    end
  end

  -- 如果缓存中没有，尝试从当前文件解析
  if not module_info then
    local current_file = vim.fn.expand('%:p')
    if not vim.fn.filereadable(current_file) then
      vim.notify('Current file is not readable', vim.log.levels.ERROR)
      return nil
    end

    local parser = require('VeriSuite.core.parser')
    local modules = parser.parse_file(current_file)

    for _, module in ipairs(modules) do
      if module.name == module_name then
        module_info = module
        break
      end
    end
  end

  -- 如果仍然没有找到，尝试从整个项目搜索
  if not module_info and use_cache then
    local module_cache_ok, module_cache = pcall(require, 'VeriSuite.core.module_cache')
    if module_cache_ok then
      -- 强制加载项目缓存
      module_cache.load_project()
      module_info = module_cache.get_module_info(module_name)
    end
  end

  if not module_info then
    vim.notify('Module "' .. module_name .. '" not found', vim.log.levels.ERROR)
    return nil
  end

  -- 生成实例化代码
  return M.auto_inst(module_info.name, module_info.parameters, module_info.ports)
end

-- 在当前缓冲区插入实例化代码
---@param module_name string
---@param line_num number? 插入的行号，默认为当前行
---@param use_cache boolean? 是否使用缓存（默认true）
function M.insert_instance_at_line(module_name, line_num, use_cache)
  local lines = M.auto_instance_by_name(module_name, use_cache)

  if not lines then
    return false
  end

  -- 确定插入位置
  local insert_line = line_num or vim.api.nvim_win_get_cursor(0)[1]

  -- 插入代码
  vim.api.nvim_buf_set_lines(0, insert_line - 1, insert_line - 1, false, lines)

  vim.notify('Generated instance for module: ' .. module_name, vim.log.levels.INFO)
  return true
end

return M
