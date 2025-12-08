local module_cache = require('VeriSuite.core.module_cache')
local parser = require('VeriSuite.core.parser')
local verible_test = require('VeriSuite.test.verible_test')

local M = {}

-- 测试项目模块缓存和依赖关系
function M.test_module_cache()
  -- 获取项目根目录
  local root_dir = parser.find_project_root()
  vim.notify('Loading modules for project: ' .. vim.fn.fnamemodify(root_dir, ':t'), vim.log.levels.INFO)

  -- 清除缓存并重新加载
  module_cache.clear_cache()
  module_cache.load_project()

  local lines = {
    '=== Module Cache Analysis ===',
    '',
    'Project root: ' .. vim.fn.fnamemodify(module_cache.get_project_root() or 'unknown', ':t'),
    'Total modules: ' .. vim.tbl_count(module_cache.cache.modules),
    'Modules with dependencies: ' .. vim.tbl_count(module_cache.cache.dependencies),
    'Modules with dependents: ' .. vim.tbl_count(module_cache.cache.dependents),
    '',
  }

  -- 统计依赖关系
  local total_deps = 0
  for _, deps in pairs(module_cache.cache.dependencies) do
    total_deps = total_deps + #deps
  end
  table.insert(lines, 'Total dependency relations: ' .. total_deps)

  -- 统计实例化数量
  local total_instances = 0
  for _, instances in pairs(module_cache.cache.instances) do
    total_instances = total_instances + #instances
  end
  table.insert(lines, 'Total module instances: ' .. total_instances)
  table.insert(lines, '')

  -- 显示所有模块及其依赖关系
  table.insert(lines, '=== Module Dependencies ===')
  for module_name, module_data in pairs(module_cache.get_dependency_tree()) do
    table.insert(lines, string.format('📦 %s', module_name))
    table.insert(lines, string.format('  File: %s', module_data.file or 'unknown'))
    table.insert(lines, string.format('  Dependencies (%d): %s', #module_data.dependencies,
      #module_data.dependencies > 0 and table.concat(module_data.dependencies, ", ") or 'none'))
    table.insert(lines, string.format('  Dependents (%d): %s', #module_data.dependents,
      #module_data.dependents > 0 and table.concat(module_data.dependents, ", ") or 'none'))
    table.insert(lines, '')
  end

  verible_test.create_result_window(lines, 'Module Cache Analysis')
end

-- 显示模块实例化关系
function M.test_module_instances()
  local root_dir = parser.find_project_root()

  -- 如果还没有加载，先加载模块缓存
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  local lines = {
    '=== Module Instance Relationships ===',
    '',
  }

  local total_instances = 0
  for file, instances in pairs(module_cache.cache.instances) do
    local file_name = vim.fn.fnamemodify(file, ':t')
    table.insert(lines, file_name .. ':')

    for _, instance in ipairs(instances) do
      table.insert(lines, string.format('  - %s -> %s',
        instance.instance_name or 'unnamed', instance.module_name or 'unknown'))
      total_instances = total_instances + 1
    end
    table.insert(lines, '')
  end

  if total_instances == 0 then
    table.insert(lines, 'No module instances found.')
  else
    table.insert(lines, 1, 'Total instances found: ' .. total_instances)
  end

  verible_test.create_result_window(lines, 'Module Instances')
end

-- 显示模块依赖关系图
function M.test_module_dependencies()
  local root_dir = parser.find_project_root()

  -- 如果还没有加载，先加载模块缓存
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  local lines = {
    '=== Module Dependency Graph ===',
    '',
  }

  local total_deps = 0
  for module_name, deps in pairs(module_cache.cache.dependencies) do
    if #deps > 0 then
      table.insert(lines, module_name .. ' depends on:')
      for _, dep in ipairs(deps) do
        table.insert(lines, '  -> ' .. dep)
        total_deps = total_deps + 1
      end
      table.insert(lines, '')
    end
  end

  if total_deps == 0 then
    table.insert(lines, 'No module dependencies found.')
  else
    table.insert(lines, 1, 'Total dependencies: ' .. total_deps)
  end

  verible_test.create_result_window(lines, 'Module Dependencies')
end

-- 显示根模块（不被其他模块依赖的模块）
function M.test_root_modules()
  local root_dir = parser.find_project_root()

  -- 如果还没有加载，先加载模块缓存
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  local lines = {
    '=== Root Modules (Entry Points) ===',
    '',
  }

  local root_modules = {}
  for module_name, module_data in pairs(module_cache.get_dependency_tree()) do
    if #module_data.dependents == 0 then
      table.insert(root_modules, module_name)
    end
  end

  if #root_modules == 0 then
    table.insert(lines, 'No root modules found (possible circular dependencies).')
  else
    table.insert(lines, 'Found ' .. #root_modules .. ' root modules:')
    table.insert(lines, '')

    for i, module_name in ipairs(root_modules) do
      local module_info = module_cache.get_module_info(module_name)
      table.insert(lines, string.format('%d. %s', i, module_name))
      table.insert(lines, '   File: ' .. (module_info and module_info.file or 'unknown'))

      local deps = module_cache.get_dependencies(module_name)
      if #deps > 0 then
        table.insert(lines, '   Dependencies: ' .. table.concat(deps, ', '))
      else
        table.insert(lines, '   Dependencies: none')
      end
      table.insert(lines, '')
    end
  end

  verible_test.create_result_window(lines, 'Root Modules')
end

-- 分析特定模块的依赖关系
function M.test_specific_module_dependencies()
  -- 获取当前打开的文件
  local current_file = vim.fn.expand('%:p')

  if current_file == '' or not vim.fn.filereadable(current_file) then
    vim.notify('No file open or file not readable', vim.log.levels.WARN)
    return
  end

  -- 如果还没有加载，先加载模块缓存
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  -- 解析当前文件获取模块名
  local modules = parser.parse_file(current_file)
  if #modules == 0 then
    vim.notify('No modules found in current file', vim.log.levels.WARN)
    return
  end

  local file_name = vim.fn.fnamemodify(current_file, ':t')
  local lines = {
    '=== Dependencies for Modules in: ' .. file_name .. ' ===',
    'Full path: ' .. current_file,
    '',
  }

  for _, module in ipairs(modules) do
    table.insert(lines, 'Module: ' .. module.name)
    table.insert(lines, '')

    -- 模块依赖关系
    local deps = module_cache.get_dependencies(module.name)
    if #deps > 0 then
      table.insert(lines, 'This module depends on:')
      for _, dep in ipairs(deps) do
        table.insert(lines, '  -> ' .. dep)
      end
      table.insert(lines, '')
    else
      table.insert(lines, 'No module dependencies found.')
      table.insert(lines, '')
    end

    -- 依赖此模块的其他模块
    local dependents = module_cache.get_dependents(module.name)
    if #dependents > 0 then
      table.insert(lines, 'Modules that depend on this module:')
      for _, dependent in ipairs(dependents) do
        table.insert(lines, '  <- ' .. dependent)
      end
      table.insert(lines, '')
    else
      table.insert(lines, 'No modules depend on this module.')
      table.insert(lines, '')
    end

    -- 模块实例化
    if module.instances and #module.instances > 0 then
      table.insert(lines, 'Module instances in this file:')
      for _, instance in ipairs(module.instances) do
        table.insert(lines, string.format('  - %s -> %s',
          instance.instance_name or 'unnamed', instance.module_name or 'unknown'))
      end
    else
      table.insert(lines, 'No module instances found in this module.')
    end

    table.insert(lines, '---')
  end

  verible_test.create_result_window(lines, 'Module Dependencies: ' .. file_name)
end

-- 重新分析项目依赖关系
function M.test_refresh_dependencies()
  local root_dir = parser.find_project_root()
  vim.notify('Refreshing module cache...', vim.log.levels.INFO)

  -- 清除缓存并重新加载
  module_cache.clear_cache()
  module_cache.load_project()

  vim.notify('Module cache refreshed', vim.log.levels.INFO)
end

-- 显示依赖关系统计信息
function M.test_dependency_stats()
  local root_dir = parser.find_project_root()

  -- 如果还没有加载，先加载模块缓存
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  local lines = {
    '=== Module Cache Statistics ===',
    '',
    'Project root: ' .. vim.fn.fnamemodify(module_cache.get_project_root() or 'unknown', ':t'),
    'Is loaded: ' .. (module_cache.cache.is_loaded and 'yes' or 'no'),
    '',
    'Counts:',
    '- Modules: ' .. vim.tbl_count(module_cache.cache.modules),
    '- Dependencies: ' .. vim.tbl_count(module_cache.cache.dependencies),
    '- Dependents: ' .. vim.tbl_count(module_cache.cache.dependents),
    '- Files with instances: ' .. vim.tbl_count(module_cache.cache.instances),
    '',
  }

  -- 统计实例数量
  local total_instances = 0
  for _, instances in pairs(module_cache.cache.instances) do
    total_instances = total_instances + #instances
  end
  table.insert(lines, '- Total module instances: ' .. total_instances)

  -- 统计依赖关系数量
  local total_deps = 0
  for _, dep_list in pairs(module_cache.cache.dependencies) do
    total_deps = total_deps + #dep_list
  end
  table.insert(lines, '- Total dependency relations: ' .. total_deps)

  -- 最复杂的模块（依赖最多的）
  local max_deps = 0
  local max_deps_module = nil
  for module_name, dep_list in pairs(module_cache.cache.dependencies) do
    if #dep_list > max_deps then
      max_deps = #dep_list
      max_deps_module = module_name
    end
  end

  if max_deps_module then
    table.insert(lines, '')
    table.insert(lines, 'Most dependent module:')
    table.insert(lines, '- ' .. max_deps_module .. ' (' .. max_deps .. ' dependencies)')
  end

  -- 被依赖最多的模块
  local max_dependents = 0
  local max_dependents_module = nil
  for module_name, dependent_list in pairs(module_cache.cache.dependents) do
    if #dependent_list > max_dependents then
      max_dependents = #dependent_list
      max_dependents_module = module_name
    end
  end

  if max_dependents_module then
    table.insert(lines, '')
    table.insert(lines, 'Most depended-upon module:')
    table.insert(lines, '- ' .. max_dependents_module .. ' (used by ' .. max_dependents .. ' modules)')
  end

  -- 实例化最多的文件
  local max_instances = 0
  local max_instances_file = nil
  for file, instances in pairs(module_cache.cache.instances) do
    if #instances > max_instances then
      max_instances = #instances
      max_instances_file = file
    end
  end

  if max_instances_file then
    table.insert(lines, '')
    table.insert(lines, 'Most instance-heavy file:')
    table.insert(lines, '- ' .. vim.fn.fnamemodify(max_instances_file, ':t') .. ' (' .. max_instances .. ' instances)')
  end

  verible_test.create_result_window(lines, 'Module Cache Statistics')
end

-- 测试特定模块（如axi_fifo）的详细信息
function M.test_specific_module_debug()
  local module_name = vim.fn.input('Module name to debug (e.g., axi_fifo): ', 'axi_fifo')
  if module_name == '' then
    return
  end

  -- 如果还没有加载，先加载模块缓存
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  local lines = {
    '=== Debug Info for Module: ' .. module_name .. ' ===',
    '',
  }

  local module_info = module_cache.get_module_info(module_name)
  if not module_info then
    table.insert(lines, 'Module not found in cache!')
    verible_test.create_result_window(lines, 'Module Debug: ' .. module_name)
    return
  end

  table.insert(lines, 'File: ' .. (module_info.file or 'unknown'))
  table.insert(lines, 'Parameters: ' .. #module_info.parameters)
  table.insert(lines, 'Ports: ' .. #module_info.ports)
  table.insert(lines, 'Instances: ' .. (module_info.instances and #module_info.instances or 0))
  table.insert(lines, '')

  -- 依赖关系
  local deps = module_cache.get_dependencies(module_name)
  table.insert(lines, 'Dependencies (' .. #deps .. '):')
  if #deps == 0 then
    table.insert(lines, '  (none)')
  else
    for i, dep in ipairs(deps) do
      table.insert(lines, '  ' .. i .. '. ' .. dep)
    end
  end
  table.insert(lines, '')

  -- 被依赖关系
  local dependents = module_cache.get_dependents(module_name)
  table.insert(lines, 'Dependents (' .. #dependents .. '):')
  if #dependents == 0 then
    table.insert(lines, '  (none) - This is a ROOT module')
  else
    for i, dependent in ipairs(dependents) do
      table.insert(lines, '  ' .. i .. '. ' .. dependent)
    end
  end
  table.insert(lines, '')

  -- 实例化信息
  if module_info.instances and #module_info.instances > 0 then
    table.insert(lines, 'Instances in this module:')
    for i, instance in ipairs(module_info.instances) do
      table.insert(lines, '  ' .. i .. '. ' .. (instance.instance_name or 'unnamed') ..
                   ' -> ' .. (instance.module_name or 'unknown'))
    end
  else
    table.insert(lines, 'No instances in this module')
  end

  verible_test.create_result_window(lines, 'Module Debug: ' .. module_name)
end

return M