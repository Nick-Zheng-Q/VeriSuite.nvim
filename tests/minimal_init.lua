-- tests/minimal_init.lua
-- Minimal init file for headless Neovim testing

-- Add current directory to runtimepath
vim.opt.runtimepath:append('.')

-- Load the plugin
local ok, err = pcall(function()
  require('VeriSuite').setup({
    enable_debug_commands = true,
    enable_autocmds = false,
  })
end)

if not ok then
  print("ERROR: Failed to load VeriSuite: " .. tostring(err))
  vim.cmd('cq! 1')
end

print("SUCCESS: VeriSuite loaded and initialized")
