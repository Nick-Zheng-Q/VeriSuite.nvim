require('digital.lsp.types')
---@class hdl_instance
---@field name string
---@field type string
---@field range range
---@field instance_module_path AbsPath | nil
---@field instance_module_path_status InstModPathStatus
---@field instance_params range | nil
---@field instance_ports range | nil
---@field parent_module hdl_module
---@field defined_module hdl_module | nil

local hdl_instance = {}

return hdl_instance
