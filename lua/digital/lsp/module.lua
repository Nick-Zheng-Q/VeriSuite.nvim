local lsp_type = require('digital.lsp.types')
---@class hdl_module
---@field hdl_file

local hdl_module = {}

---@param file string
function hdl_module.init(file, name, range, params, ports, instances)
  hdl_module['file'] = file
  hdl_module['name'] = name
  hdl_module['range'] = range
  hdl_module['params'] = params
  hdl_module['ports'] = ports
  hdl_module['instances'] = instances
end

---@class hdl_module_port
---@field name string
---@field type HDL_MODULE_PORT_TYPE
---@field width string
---@field range range
---@field desc string
---@field signed string
---@field netType string
function hdl_module.hdl_module_port(name, type, width, range, desc, signed, netType)
  local table = {}
  table['name'] = name
  table['type'] = type
  table['width'] = width
  table['range'] = range
  table['desc'] = desc
  table['signed'] = signed
  table['netType'] = netType
  return table
end

---@class hdl_module_param
---@field name string
---@field type string
---@field init string
---@field range range
---@field desc string
function hdl_module.hdl_module_param(name, type, init, range, desc)
  local table = {}
  table['name'] = name
  table['type'] = type
  table['init'] = init
  table['range'] = range
  table['desc'] = desc
  return table
end

return hdl_module
