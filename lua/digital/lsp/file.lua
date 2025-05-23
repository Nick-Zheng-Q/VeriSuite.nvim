local global = require('digital.lsp.init')
---@class hdl_file
---@field path string
---@field language_id HDL_LANG_ID
---@field project_type HDL_FILE_PROJECT_TYPE
---@field name table: Map<string, hdl_module>
local hdl_file = {}

function hdl_file.new(path, language_id, project_type)
  local self = {
    path = path,
    language_id = language_id,
    project_type = project_type,
  }
  global.hdl_param.set_hdl_file(self)
end

return hdl_file
