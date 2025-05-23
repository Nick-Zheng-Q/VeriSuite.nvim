if vim.g.digital_version then
  return
end

vim.g.digital_version = '0.0.1'

if vim.fn.has('nvim-0.11') ~= 1 then
  vim.notify_once('digital requires Neovim 0.11 or above', vim.log.levels.ERROR)
  return
end

---@type digital.Config
local config = require('digital')

-- if not vim.g.loaded_digital then
--
-- end

local auto_attach = config.ser
