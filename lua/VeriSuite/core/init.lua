local verible = require('VeriSuite.core.verible')
local M = {}

function M.check_availibility()
  if verible.is_available() then
    vim.notify('verible available')
  end
end

return M
