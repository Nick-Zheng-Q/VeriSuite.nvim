local verible = require('VeriSuite.core.verible')
local autogen = require('VeriSuite.core.autoinst')
local parser = require('VeriSuite.core.parser')
local module_cache = require('VeriSuite.core.module_cache')
local M = {}

function M.check_availibility()
  if verible.is_available() then
    vim.notify('verible available')
  end
end

function M.register_core_commands()
  vim.api.nvim_create_user_command('VeriSuiteAutoInst', function()
    local module_name = vim.fn.input('Enter module name: ')
    if module_name ~= '' then
      autogen.insert_instance_at_line(module_name)
    end
  end, {})
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
