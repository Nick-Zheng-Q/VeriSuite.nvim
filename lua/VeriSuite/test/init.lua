local verible_test = require('VeriSuite.test.verible_test')
local autoinst_test = require('VeriSuite.test.autoinst_test')
local dependency_test = require('VeriSuite.test.dependency_test')
local treeview = require('VeriSuite.core.treeview')
local M = {}

local function reload_plugin()
  for plugin_name, _ in pairs(package.loaded) do
    if plugin_name:match('VeriSuite') then
      package.loaded[plugin_name] = nil
    end
  end
  require('VeriSuite').setup()
end

function M.register_debug_commands()
  vim.keymap.set({ 'n' }, '<leader>pt', reload_plugin, {
    desc = 'quick reload VeriSuite',
  })
  vim.api.nvim_create_user_command('VeriSuiteDebugParseFile', function()
    verible_test.test_parse_file()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteDebugParseProject', function()
    verible_test.test_parse_project()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteDebugParseFileRaw', function()
    verible_test.test_parse_file_raw()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteDebugShowConfig', function()
    verible_test.test_show_config()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteDebugTreeStructure', function()
    verible_test.test_tree_structure()
  end, {})

  -- 自动实例化测试命令
  vim.api.nvim_create_user_command('VeriSuiteTestAutoInst', function()
    autoinst_test.test_manual_auto_instance()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTestGenerateOnly', function()
    autoinst_test.test_generate_only()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteExpandAuto', function()
    local auto = require('VeriSuite.core.auto')
    auto.expand_current_buffer()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteUndoAuto', function()
    local auto = require('VeriSuite.core.auto')
    auto.undo_last()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTestModuleInstances', function()
    dependency_test.test_module_instances()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTestModuleDependencies', function()
    dependency_test.test_module_dependencies()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTestRootModules', function()
    dependency_test.test_root_modules()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTestSpecificModuleDeps', function()
    dependency_test.test_specific_module_dependencies()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTestRefreshDeps', function()
    dependency_test.test_refresh_dependencies()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTestDependencyStats', function()
    dependency_test.test_dependency_stats()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTestSpecificModuleDebug', function()
    dependency_test.test_specific_module_debug()
  end, {})

  -- Treeview 相关命令
  vim.api.nvim_create_user_command('VeriSuiteTreeViewToggle', function()
    if treeview.window_state.is_open then
      treeview.close_dependency_tree()
    else
      treeview.show_dependency_tree({ filter_type = 'all' })
    end
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTreeViewHardware', function()
    treeview.window_state.filter_type = 'hw'
    if not treeview.window_state.is_open then
      treeview.show_dependency_tree({ filter_type = 'hw' })
    else
      treeview.refresh_tree()
    end
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTreeViewTest', function()
    treeview.window_state.filter_type = 'test'
    if not treeview.window_state.is_open then
      treeview.show_dependency_tree({ filter_type = 'test' })
    else
      treeview.refresh_tree()
    end
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTreeViewClose', function()
    treeview.close_dependency_tree()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTreeViewRefresh', function()
    treeview.refresh_with_analysis()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTreeViewClose', function()
    treeview.close_dependency_tree()
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteTestModuleExtraction', function()
    treeview.test_module_extraction()
  end, {})

  -- Module cache 相关命令
  vim.api.nvim_create_user_command('VeriSuiteTestModuleCache', function()
    local module_cache = require('VeriSuite.core.module_cache')

    -- 清除缓存并重新加载
    module_cache.clear_cache()
    module_cache.load_project()

    vim.notify('Module cache loaded with ' .. vim.tbl_count(module_cache.cache.modules) .. ' modules', vim.log.levels.INFO)

    -- 显示依赖关系统计
    local total_deps = 0
    for _, deps in pairs(module_cache.cache.dependencies) do
      total_deps = total_deps + #deps
    end

    vim.notify('Total dependencies: ' .. total_deps, vim.log.levels.INFO)

    -- 显示前几个模块的依赖关系
    local count = 0
    for module_name, deps in pairs(module_cache.cache.dependencies) do
      if count < 5 and #deps > 0 then
        vim.notify(module_name .. ' depends on: ' .. table.concat(deps, ', '), vim.log.levels.INFO)
        count = count + 1
      end
    end
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteDebugCacheStatus', function()
    local module_cache = require('VeriSuite.core.module_cache')
    local stats = module_cache.status()
    local summary = string.format(
      'Modules: %d, dependencies: %d, files cached: %d',
      stats.modules,
      stats.dependencies,
      stats.files_cached
    )
    vim.notify(summary, vim.log.levels.INFO)
    if stats.project_root then
      vim.notify('Project root: ' .. stats.project_root, vim.log.levels.DEBUG)
    end
  end, {})

  vim.api.nvim_create_user_command('VeriSuiteAutoArg', function()
    local auto = require('VeriSuite.core.auto')
    auto.expand_markers({ 'AUTOARG' })
  end, { desc = 'Expand AUTOARG markers' })

  vim.api.nvim_create_user_command('VeriSuiteAutoInput', function()
    local auto = require('VeriSuite.core.auto')
    auto.expand_markers({ 'AUTOINPUT' })
  end, { desc = 'Expand AUTOINPUT markers' })

  vim.api.nvim_create_user_command('VeriSuiteAutoOutput', function()
    local auto = require('VeriSuite.core.auto')
    auto.expand_markers({ 'AUTOOUTPUT' })
  end, { desc = 'Expand AUTOOUTPUT markers' })

  vim.api.nvim_create_user_command('VeriSuiteAutoWire', function()
    local auto = require('VeriSuite.core.auto')
    auto.expand_markers({ 'AUTOWIRE' })
  end, { desc = 'Expand AUTOWIRE markers' })

  vim.api.nvim_create_user_command('VeriSuiteAutoReg', function()
    local auto = require('VeriSuite.core.auto')
    auto.expand_markers({ 'AUTOREG' })
  end, { desc = 'Expand AUTOREG markers' })

  vim.api.nvim_create_user_command('VeriSuiteAutoInout', function()
    local auto = require('VeriSuite.core.auto')
    auto.expand_markers({ 'AUTOINOUT' })
  end, { desc = 'Expand AUTOINOUT markers' })
end

return M
