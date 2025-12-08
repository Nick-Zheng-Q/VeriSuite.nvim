-- lua/VeriSuite/core/dependency_analyzer.lua
local verible = require('VeriSuite.core.verible')

local dependency_analyzer = {}

-- 依赖关系数据结构
dependency_analyzer.dependencies = {
  -- 文件级依赖关系
  file_dependencies = {}, -- file -> {dependent_files}

  -- 模块级依赖关系
  module_dependencies = {}, -- module -> {dependent_modules}

  -- 模块实例化关系
  module_instances = {}, -- file -> {instances}

  -- 符号引用关系
  symbol_references = {}, -- symbol -> {referencing_files}

  -- 项目根目录
  project_root = nil,

  -- 最后更新时间
  last_update = nil,
}

-- 分析项目依赖关系
function dependency_analyzer.analyze_project_dependencies(root_dir)
  local parser = require('VeriSuite.core.parser')
  local files = parser.find_verilog_files(root_dir)

  if #files == 0 then
    vim.notify('No Verilog files found for dependency analysis', vim.log.levels.WARN)
    return
  end

  print('Analyzing dependencies for ' .. #files .. ' files...')

  -- 重置依赖关系缓存
  dependency_analyzer.reset_dependencies()
  dependency_analyzer.dependencies.project_root = root_dir
  dependency_analyzer.dependencies.last_update = os.time()

  -- 1. 分析文件级依赖关系
  dependency_analyzer.analyze_file_dependencies(files)

  -- 2. 分析符号引用关系
  dependency_analyzer.analyze_symbol_references(files)

  -- 3. 构建模块依赖关系
  dependency_analyzer.build_module_dependencies()

  print('Dependency analysis completed')
  dependency_analyzer.print_dependency_summary()
end

-- 重置依赖关系缓存
function dependency_analyzer.reset_dependencies()
  dependency_analyzer.dependencies = {
    file_dependencies = {},
    module_dependencies = {},
    module_instances = {},
    symbol_references = {},
    project_root = nil,
    last_update = nil,
  }
end

-- 分析文件级依赖关系 (使用 file-deps)
function dependency_analyzer.analyze_file_dependencies(files)
  local file_list_path = dependency_analyzer.create_temp_file_list(files)

  local cmd = string.format(
    '%s file-deps --file_list_path=%s',
    verible.tools.project_tool,
    vim.fn.shellescape(file_list_path)
  )

  print('Running file-deps analysis...')
  local result = vim.fn.system(cmd)

  -- 清理临时文件
  os.remove(file_list_path)

  -- 检查是否有输出（不管退出码）
  if result and string.len(result) > 10 then
    dependency_analyzer.parse_file_deps_output(result)
    print('file-deps analysis completed')
  else
    print('No file dependencies found')
  end
end

-- 分析符号引用关系 (使用 symbol-table-refs)
function dependency_analyzer.analyze_symbol_references(files)
  local file_list_path = dependency_analyzer.create_temp_file_list(files)

  local cmd = string.format(
    '%s symbol-table-refs --file_list_path=%s',
    verible.tools.project_tool,
    vim.fn.shellescape(file_list_path)
  )

  print('Running symbol-table-refs analysis...')
  local result = vim.fn.system(cmd)

  -- 清理临时文件
  os.remove(file_list_path)

  -- 检查是否有输出（不管退出码）
  if result and string.len(result) > 10 then
    dependency_analyzer.parse_symbol_refs_output(result)
  else
    print('No symbol references found')
  end
end

-- 创建临时文件列表
function dependency_analyzer.create_temp_file_list(files)
  local file_list_path = '/tmp/verisuite_deps_' .. os.time() .. '.txt'
  local file_list = io.open(file_list_path, 'w')

  if file_list then
    for _, file in ipairs(files) do
      file_list:write(file .. '\n')
    end
    file_list:close()
  end

  return file_list_path
end

-- 解析 file-deps 输出
function dependency_analyzer.parse_file_deps_output(output)
  local lines = vim.split(output, '\n')

  for _, line in ipairs(lines) do
    -- 匹配格式: "foo.sv" depends on "bar.sv" for symbols { bar baz }
    local file_dep = string.match(line, '^"([^"]+)" depends on "([^"]+)" for symbols')
    if file_dep then
      local from_file, to_file = string.match(file_dep, '^(.+) depends on (.+)$')
      if from_file and to_file then
        dependency_analyzer.add_file_dependency(from_file, to_file)
      end
    end
  end
end

-- 解析 symbol-table-refs 输出
function dependency_analyzer.parse_symbol_refs_output(output)
  local lines = vim.split(output, '\n')
  local current_module = nil
  local unresolved_count = 0
  local module_dep_count = 0

  for _, line in ipairs(lines) do
    -- 检测模块上下文 (格式:    module_name: { (refs: ...)
    local module_match = string.match(line, '^%s*([^:]+):%s*%{%(refs:')
    if module_match and module_match ~= 'Symbol' then
      current_module = module_match
    end

    -- 解析未解析的符号 (格式: Unable to resolve symbol "SYMBOL_NAME" from context $root::MODULE_NAME.)
    local symbol, context = string.match(line, 'Unable to resolve symbol "([^"]+)" from context %$root::([^%.]+)')
    if symbol and context then
      dependency_analyzer.add_unresolved_symbol(context, context, symbol)
      unresolved_count = unresolved_count + 1
    end

    -- 查找模块引用 (在symbol-table-refs输出中，模块引用会出现在error部分)
    local referenced_module, current_module_name = string.match(line, 'No member symbol "([^"]+)" in parent scope %(module%) ([^%.]+)')
    if referenced_module and current_module_name and referenced_module ~= current_module_name then
      dependency_analyzer.add_module_dependency(current_module_name, referenced_module)
      module_dep_count = module_dep_count + 1
    end
  end

  if unresolved_count > 0 or module_dep_count > 0 then
    print('Parsed ' .. unresolved_count .. ' unresolved symbols and ' .. module_dep_count .. ' module dependencies')
  end
end

-- 添加文件依赖关系
function dependency_analyzer.add_file_dependency(from_file, to_file)
  if not dependency_analyzer.dependencies.file_dependencies[from_file] then
    dependency_analyzer.dependencies.file_dependencies[from_file] = {}
  end
  table.insert(dependency_analyzer.dependencies.file_dependencies[from_file], to_file)
end

-- 添加模块实例化
function dependency_analyzer.add_module_instance(file, target_module, instance_name, instance_type)
  if not dependency_analyzer.dependencies.module_instances[file] then
    dependency_analyzer.dependencies.module_instances[file] = {}
  end

  table.insert(dependency_analyzer.dependencies.module_instances[file], {
    target_module = target_module,
    instance_name = instance_name,
    instance_type = instance_type,
  })

  -- 同时添加模块依赖关系
  dependency_analyzer.add_module_dependency(file, target_module)
end

-- 添加未解析符号
function dependency_analyzer.add_unresolved_symbol(file, context, symbol)
  local key = context .. '::' .. symbol
  if not dependency_analyzer.dependencies.symbol_references[key] then
    dependency_analyzer.dependencies.symbol_references[key] = {}
  end
  table.insert(dependency_analyzer.dependencies.symbol_references[key], file)
end

-- 添加模块依赖关系
function dependency_analyzer.add_module_dependency(from_file, to_module)
  if not dependency_analyzer.dependencies.module_dependencies[from_file] then
    dependency_analyzer.dependencies.module_dependencies[from_file] = {}
  end
  table.insert(dependency_analyzer.dependencies.module_dependencies[from_file], to_module)
end

-- 构建模块依赖关系
function dependency_analyzer.build_module_dependencies()
  -- 基于实例化关系构建模块依赖图
  -- 这里可以添加更复杂的分析逻辑
end

-- 打印依赖关系摘要
function dependency_analyzer.print_dependency_summary()
  local deps = dependency_analyzer.dependencies

  print('\n=== Dependency Analysis Summary ===')
  print('File dependencies: ' .. vim.tbl_count(deps.file_dependencies))
  print('Module dependencies: ' .. vim.tbl_count(deps.module_dependencies))
  print('Module instances: ' .. vim.tbl_count(deps.module_instances))
  print('Unresolved symbols: ' .. vim.tbl_count(deps.symbol_references))
end

-- 获取文件的依赖关系
function dependency_analyzer.get_file_dependencies(file)
  return dependency_analyzer.dependencies.file_dependencies[file] or {}
end

-- 获取文件中的模块实例化
function dependency_analyzer.get_module_instances(file)
  return dependency_analyzer.dependencies.module_instances[file] or {}
end

-- 获取依赖某个文件的所有文件
function dependency_analyzer.get_dependents_of_file(file)
  local dependents = {}
  for from_file, to_files in pairs(dependency_analyzer.dependencies.file_dependencies) do
    for _, to_file in ipairs(to_files) do
      if to_file == file then
        table.insert(dependents, from_file)
      end
    end
  end
  return dependents
end

-- 获取项目的编译顺序（拓扑排序）
function dependency_analyzer.get_compilation_order()
  local order = {}
  local visited = {}
  local temp_visited = {}

  local function visit(file)
    if temp_visited[file] then
      print('Warning: Circular dependency detected involving ' .. file)
      return
    end

    if visited[file] then
      return
    end

    temp_visited[file] = true

    local deps = dependency_analyzer.get_file_dependencies(file)
    for _, dep in ipairs(deps) do
      visit(dep)
    end

    temp_visited[file] = false
    visited[file] = true
    table.insert(order, file)
  end

  -- 访问所有文件
  for file, _ in pairs(dependency_analyzer.dependencies.file_dependencies) do
    if not visited[file] then
      visit(file)
    end
  end

  return order
end

-- 清除依赖关系缓存
function dependency_analyzer.clear_cache()
  dependency_analyzer.reset_dependencies()
end

return dependency_analyzer