---@class hdl_param
local M = {}

function M.new()
  local self = {
    top_modules = {}, -- Set<HdlModule>
    src_top_modules = {},
    sim_top_modules = {},
    path_to_hdl_files = {},
    modules = {},
    unhandle_instances = {},
  }

  function self:has_hdl_file(path)
    return self.path_to_hdl_files[path] ~= nil
  end

  function self:get_hdl_file(path)
    return self.path_to_hdl_files[path]
  end

  function self:set_hdl_file(hdl_file)
    self.path_to_hdl_files[hdl_file.path] = hdl_file
  end

  return self
end

return M
