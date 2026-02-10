local verible = require('VeriSuite.core.verible')
local autogen = require('VeriSuite.core.autoinst')
local parser = require('VeriSuite.core.parser')
local module_cache = require('VeriSuite.core.module_cache')
local treeview = require('VeriSuite.core.treeview')
local auto = require('VeriSuite.core.auto')
local M = {}

local function create_command_once(name, rhs, opts)
  if vim.fn.exists(':' .. name) == 2 then
    return
  end
  vim.api.nvim_create_user_command(name, rhs, opts or {})
end

function M.check_availibility()
  if verible.is_available() then
    vim.notify('verible available')
  end
end

function M.register_core_commands()
  create_command_once('VeriSuiteAutoInst', function()
    local module_name = vim.fn.input('Enter module name: ')
    if module_name ~= '' then
      autogen.insert_instance_at_line(module_name)
    end
  end, {})

  create_command_once('VeriSuiteParseProject', function()
    module_cache.load_project()
  end, { desc = 'Parse project and load module cache' })

  create_command_once('VeriSuiteExpandAuto', function()
    auto.expand_current_buffer()
  end, { desc = 'Expand all AUTO markers in current buffer' })

  create_command_once('VeriSuiteUndoAuto', function()
    auto.undo_last()
  end, { desc = 'Undo last AUTO expansion' })

  create_command_once('VeriSuiteAutoArg', function()
    auto.expand_markers({ 'AUTOARG' })
  end, { desc = 'Expand AUTOARG markers' })

  create_command_once('VeriSuiteAutoInput', function()
    auto.expand_markers({ 'AUTOINPUT' })
  end, { desc = 'Expand AUTOINPUT markers' })

  create_command_once('VeriSuiteAutoOutput', function()
    auto.expand_markers({ 'AUTOOUTPUT' })
  end, { desc = 'Expand AUTOOUTPUT markers' })

  create_command_once('VeriSuiteAutoWire', function()
    auto.expand_markers({ 'AUTOWIRE' })
  end, { desc = 'Expand AUTOWIRE markers' })

  create_command_once('VeriSuiteAutoReg', function()
    auto.expand_markers({ 'AUTOREG' })
  end, { desc = 'Expand AUTOREG markers' })

  create_command_once('VeriSuiteAutoInout', function()
    auto.expand_markers({ 'AUTOINOUT' })
  end, { desc = 'Expand AUTOINOUT markers' })

  create_command_once('VeriSuiteTreeViewToggle', function()
    if treeview.window_state.is_open then
      treeview.close_dependency_tree()
    else
      treeview.show_dependency_tree({ filter_type = 'all' })
    end
  end, { desc = 'Toggle dependency tree view' })

  create_command_once('VeriSuiteTreeViewHardware', function()
    treeview.window_state.filter_type = 'hw'
    if not treeview.window_state.is_open then
      treeview.show_dependency_tree({ filter_type = 'hw' })
    else
      treeview.refresh_tree()
    end
  end, { desc = 'Show hardware dependency tree' })

  create_command_once('VeriSuiteTreeViewTest', function()
    treeview.window_state.filter_type = 'test'
    if not treeview.window_state.is_open then
      treeview.show_dependency_tree({ filter_type = 'test' })
    else
      treeview.refresh_tree()
    end
  end, { desc = 'Show test dependency tree' })

  create_command_once('VeriSuiteTreeViewClose', function()
    treeview.close_dependency_tree()
  end, { desc = 'Close dependency tree view' })

  create_command_once('VeriSuiteTreeViewRefresh', function()
    treeview.refresh_with_analysis()
  end, { desc = 'Refresh dependency tree view' })
end

function M.register_autocmds()
  local group = vim.api.nvim_create_augroup('VeriSuiteAutoUpdate', { clear = true })

  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = { '*.v', '*.sv', '*.vh', '*.svh' },
    callback = function()
      module_cache.auto_update_current_file()
    end,
    desc = 'VeriSuite: refresh module cache for saved Verilog files',
  })
end

return M
