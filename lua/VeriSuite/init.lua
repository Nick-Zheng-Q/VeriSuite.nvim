local core = require('VeriSuite.core')
local test = require('VeriSuite.test')
local M = {}

test.register_debug_commands()
function M.setup()
  vim.notify('loaded Verisuite.nvim notify')
  core.check_availibility()
end

return M
