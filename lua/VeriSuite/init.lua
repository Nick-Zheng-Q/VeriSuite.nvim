local core = require('VeriSuite.core')
local verible = require('VeriSuite.core.verible')
local test = require('VeriSuite.test')
local blink = require('VeriSuite.integrations.blink')
local fzf = require('VeriSuite.integrations.fzf')
local keymapping = require('VeriSuite.config.keymapping')
local parser = require('VeriSuite.core.parser')
local M = {}

local defaults = {
  enable_debug_commands = true,
  enable_autocmds = true,
  verible = {},
  enable_blink_source = false,
  blink = {},
  enable_fzf = false,
  enable_fidget = false,
  keymaps = {},
  project = {
    extensions = { '.v', '.sv', '.vh', '.svh' },
    library_directories = {},
    library_files = {},
    include_dirs = {},
    defines = {},
    parse_preprocessor = false,
  },
}

---Setup entry point
---@param opts table|nil
function M.setup(opts)
  local config = vim.tbl_deep_extend('force', defaults, opts or {})

  verible.setup(config.verible)
  parser.set_options(config.project)
  vim.g.VeriSuiteEnableFidget = config.enable_fidget
  core.check_availibility()
  core.register_core_commands()

  if config.enable_autocmds then
    core.register_autocmds()
  end

  if config.enable_blink_source then
    blink.configure(config.blink)
  end

  if config.enable_fzf then
    fzf.register_command()
  end

  if config.enable_debug_commands then
    test.register_debug_commands()
  end

  keymapping.apply(config.keymaps)

  vim.notify('VeriSuite.nvim loaded', vim.log.levels.DEBUG)
end

return M
