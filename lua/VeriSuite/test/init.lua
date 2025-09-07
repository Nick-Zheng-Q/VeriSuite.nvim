local verible_test = require('VeriSuite.test.verible_test')
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
end

return M
