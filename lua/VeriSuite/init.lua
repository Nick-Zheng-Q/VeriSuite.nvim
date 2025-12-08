local core = require('VeriSuite.core')
local verible = require('VeriSuite.core.verible')
local test = require('VeriSuite.test')
local M = {}

local defaults = {
  enable_debug_commands = true,
  enable_autocmds = true,
  verible = {},
}

---Setup entry point
---@param opts table|nil
function M.setup(opts)
  local config = vim.tbl_deep_extend('force', defaults, opts or {})

  verible.setup(config.verible)
  core.check_availibility()
  core.register_core_commands()

  if config.enable_autocmds then
    core.register_autocmds()
  end

  if config.enable_debug_commands then
    test.register_debug_commands()
  end

  vim.notify('VeriSuite.nvim loaded', vim.log.levels.DEBUG)
end

return M
