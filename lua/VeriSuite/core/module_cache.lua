-- lua/VeriSuite/module_cache.lua
local module_cache = {}
local fidget = require('VeriSuite.integrations.fidget')

-- 全局缓存表
module_cache.cache = {
  modules = {}, -- 模块信息缓存
  last_update = {}, -- 每个文件的最后更新时间
  project_root = nil, -- 项目根目录
  is_loaded = false, -- 是否已加载
  -- 新增依赖关系信息
  dependencies = {}, -- 模块依赖关系: module_name -> {dependent_modules}
  dependents = {},   -- 反向依赖关系: module_name -> {modules_that_depend_on_this}
  instances = {},    -- 实例化信息: file_path -> {instances}
  loading = false,   -- 异步加载状态
}

-- 初始化缓存
function module_cache.init()
  module_cache.cache.modules = {}
  module_cache.cache.last_update = {}
  module_cache.cache.project_root = nil
  module_cache.cache.is_loaded = false
  -- 初始化依赖关系信息
  module_cache.cache.dependencies = {}
  module_cache.cache.dependents = {}
  module_cache.cache.instances = {}
end

-- 获取项目根目录
function module_cache.get_project_root()
  if module_cache.cache.project_root then
    return module_cache.cache.project_root
  end

  local parser = require('VeriSuite.core.parser')
  module_cache.cache.project_root = parser.find_project_root()
  return module_cache.cache.project_root
end

-- 检查文件是否需要重新解析
function module_cache.needs_update(file_path)
  local last_modified = vim.fn.getftime(file_path)
  local cached_time = module_cache.cache.last_update[file_path]

  return not cached_time or last_modified > cached_time
end

-- 解析并缓存单个文件
function module_cache.parse_and_cache_file(file_path)
  local parser = require('VeriSuite.core.parser')

  -- 解析文件
  local modules = parser.parse_file(file_path)

  -- 缓存结果并提取实例化信息
  for _, module in ipairs(modules) do
    module_cache.cache.modules[module.name] = module

    -- 处理实例化信息，构建依赖关系
    if module.instances and #module.instances > 0 then
      module_cache.cache.instances[file_path] = module.instances

      -- 构建依赖关系
      for _, instance in ipairs(module.instances) do
        if instance.module_name and instance.module_name ~= "" then
          -- 添加依赖关系：当前模块依赖被实例化的模块
          module_cache.add_dependency(module.name, instance.module_name)
        end
      end
    end
  end

  -- 更新时间戳
  module_cache.cache.last_update[file_path] = vim.fn.getftime(file_path)

  return modules
end

-- 添加模块依赖关系
function module_cache.add_dependency(module_name, dependency_name)
  if not module_cache.cache.dependencies[module_name] then
    module_cache.cache.dependencies[module_name] = {}
  end

  -- 避免重复添加
  for _, dep in ipairs(module_cache.cache.dependencies[module_name]) do
    if dep == dependency_name then
      return
    end
  end

  table.insert(module_cache.cache.dependencies[module_name], dependency_name)

  -- 同时更新反向依赖关系
  if not module_cache.cache.dependents[dependency_name] then
    module_cache.cache.dependents[dependency_name] = {}
  end

  for _, dependent in ipairs(module_cache.cache.dependents[dependency_name]) do
    if dependent == module_name then
      return
    end
  end

  table.insert(module_cache.cache.dependents[dependency_name], module_name)
end

-- 加载整个项目到缓存
function module_cache.load_project()
  if module_cache.cache.loading then
    vim.notify('VeriSuite: module cache is already loading', vim.log.levels.INFO)
    return
  end

  local parser = require('VeriSuite.core.parser')
  local root_dir = module_cache.get_project_root()

  module_cache.cache.loading = true
  module_cache.init()
  module_cache.cache.project_root = root_dir

  local progress_handle = nil
  if vim.g.VeriSuiteEnableFidget then
    progress_handle = fidget.create('VeriSuite', 'Parsing project')
  end

  parser.parse_project_async(root_dir, {
    concurrency = 4,
    on_progress = function(done, total)
      if progress_handle and total > 0 then
        local pct = math.floor((done / total) * 100)
        fidget.report(progress_handle, string.format('Parsing %d/%d', done, total), pct)
      end
      if done % 20 == 0 or done == total then
        vim.notify(string.format('VeriSuite cache parsing %d/%d files', done, total), vim.log.levels.DEBUG)
      end
    end,
    on_finish = function(modules, failed, errors)
      -- 重建缓存
      module_cache.init()
      module_cache.cache.project_root = root_dir

      for _, module in ipairs(modules) do
        module_cache.cache.modules[module.name] = module
        module_cache.cache.last_update[module.file] = vim.fn.getftime(module.file)

        if module.instances and #module.instances > 0 then
          module_cache.cache.instances[module.file] = module.instances
          for _, instance in ipairs(module.instances) do
            if instance.module_name and instance.module_name ~= '' then
              module_cache.add_dependency(module.name, instance.module_name)
            end
          end
        end
      end

      module_cache.cache.is_loaded = true
      module_cache.cache.loading = false

      local dependency_count = 0
      for _, deps in pairs(module_cache.cache.dependencies) do
        dependency_count = dependency_count + #deps
      end

      local msg = string.format(
        'Loaded %d modules, %d dependencies (failed files: %d)',
        vim.tbl_count(module_cache.cache.modules),
        dependency_count,
        failed or 0
      )
      vim.notify(msg, vim.log.levels.INFO)
      if progress_handle then
        fidget.finish(progress_handle, msg)
      end

      if errors and #errors > 0 then
        local first = errors[1]
        local detail = first.err or ''
        vim.notify(
          string.format('First parse failure: %s (%s)', first.file or 'unknown', detail),
          vim.log.levels.WARN
        )
      end
    end,
  })
end

-- 重新加载缓存（增量更新）
function module_cache.reload_cache()
  local parser = require('VeriSuite.core.parser')
  local root_dir = module_cache.get_project_root()
  module_cache.cache.loading = true

  local progress_handle = nil
  if vim.g.VeriSuiteEnableFidget then
    progress_handle = fidget.create('VeriSuite', 'Reloading cache')
  end

  parser.parse_project_async(root_dir, {
    concurrency = 4,
    on_progress = function(done, total)
      if progress_handle and total > 0 then
        local pct = math.floor((done / total) * 100)
        fidget.report(progress_handle, string.format('Reloading %d/%d', done, total), pct)
      end
    end,
    on_finish = function(modules, failed, errors)
      -- 简单策略：重建缓存
      module_cache.init()
      module_cache.cache.project_root = root_dir

      for _, module in ipairs(modules) do
        module_cache.cache.modules[module.name] = module
        module_cache.cache.last_update[module.file] = vim.fn.getftime(module.file)
        if module.instances and #module.instances > 0 then
          module_cache.cache.instances[module.file] = module.instances
          for _, instance in ipairs(module.instances) do
            if instance.module_name and instance.module_name ~= '' then
              module_cache.add_dependency(module.name, instance.module_name)
            end
          end
        end
      end

      module_cache.cache.is_loaded = true
      module_cache.cache.loading = false

      local dependency_count = 0
      for _, deps in pairs(module_cache.cache.dependencies) do
        dependency_count = dependency_count + #deps
      end

      local msg = string.format(
        'Reloaded %d modules, %d dependencies (failed files: %d)',
        vim.tbl_count(module_cache.cache.modules),
        dependency_count,
        failed or 0
      )
      vim.notify(msg, vim.log.levels.INFO)
      if progress_handle then
        fidget.finish(progress_handle, msg)
      end
      if errors and #errors > 0 then
        vim.notify(
          string.format('First parse failure: %s (%s)', errors[1].file or 'unknown', errors[1].err or ''),
          vim.log.levels.WARN
        )
      end
    end,
  })
end

-- 移除不存在的文件及其模块/依赖
function module_cache.prune_missing_files()
  local removed_modules = 0

  for module_name, module in pairs(module_cache.cache.modules) do
    if module.file and vim.fn.filereadable(module.file) == 0 then
      -- 清理依赖映射
      module_cache.cache.dependencies[module_name] = nil
      for _, deps in pairs(module_cache.cache.dependencies) do
        for i = #deps, 1, -1 do
          if deps[i] == module_name then
            table.remove(deps, i)
          end
        end
      end

      for _, deps in pairs(module_cache.cache.dependents) do
        for i = #deps, 1, -1 do
          if deps[i] == module_name then
            table.remove(deps, i)
          end
        end
      end

      module_cache.cache.modules[module_name] = nil
      removed_modules = removed_modules + 1
    end
  end

  for file_path, _ in pairs(module_cache.cache.last_update) do
    if vim.fn.filereadable(file_path) == 0 then
      module_cache.cache.last_update[file_path] = nil
      module_cache.cache.instances[file_path] = nil
    end
  end

  return removed_modules
end

-- 获取模块信息
function module_cache.get_module_info(module_name)
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  return module_cache.cache.modules[module_name]
end

-- 获取所有模块名称（用于自动补全）
function module_cache.get_module_names()
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  local names = {}
  for module_name, _ in pairs(module_cache.cache.modules) do
    table.insert(names, module_name)
  end

  return names
end

-- 模糊搜索模块
function module_cache.search_modules(query)
  local all_names = module_cache.get_module_names()
  local results = {}

  for _, name in ipairs(all_names) do
    if string.find(string.lower(name), string.lower(query)) then
      table.insert(results, name)
    end
  end

  return results
end

-- 获取模块的依赖关系
function module_cache.get_dependencies(module_name)
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  return module_cache.cache.dependencies[module_name] or {}
end

-- 获取依赖某个模块的所有模块（反向依赖）
function module_cache.get_dependents(module_name)
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  return module_cache.cache.dependents[module_name] or {}
end

-- 获取文件中的实例化信息
function module_cache.get_file_instances(file_path)
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  return module_cache.cache.instances[file_path] or {}
end

-- 获取完整的依赖树（用于可视化）
function module_cache.get_dependency_tree()
  if not module_cache.cache.is_loaded then
    module_cache.load_project()
  end

  local tree = {}
  for module_name, dependencies in pairs(module_cache.cache.dependencies) do
    tree[module_name] = {
      dependencies = dependencies,
      dependents = module_cache.cache.dependents[module_name] or {},
      file = module_cache.cache.modules[module_name] and module_cache.cache.modules[module_name].file
    }
  end

  return tree
end

-- 清除缓存
function module_cache.clear_cache()
  module_cache.init()
end

-- 自动更新缓存（文件保存时调用）
function module_cache.auto_update_current_file()
  local current_file = vim.fn.expand('%:p')
  if current_file and vim.fn.filereadable(current_file) == 1 then
    if string.match(current_file, '%.v$') or string.match(current_file, '%.sv$') then
      module_cache.parse_and_cache_file(current_file)
    end
  end
end

-- 缓存状态汇总
function module_cache.status()
  local dep_count = 0
  for _, deps in pairs(module_cache.cache.dependencies) do
    dep_count = dep_count + #deps
  end

  return {
    modules = vim.tbl_count(module_cache.cache.modules),
    dependencies = dep_count,
    files_cached = vim.tbl_count(module_cache.cache.last_update),
    project_root = module_cache.cache.project_root,
    is_loaded = module_cache.cache.is_loaded,
  }
end

return module_cache
