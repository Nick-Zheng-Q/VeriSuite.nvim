local function get_header_items(file_path)
  local stext = io.open(file_path):read('*a')
  local name = get_query(stext, '((module_keyword) (simple_identifier) @module_name)')
  local params = {
    idents = get_query(
      stext,
      '(parameter_declaration (list_of_param_assignments (param_assignment (simple_identifier) @param_name )))'
    ),
    consts = get_query(
      stext,
      '(parameter_declaration (list_of_param_assignments (param_assignment (constant_param_expression) @param_value)))'
    ),
  }

  local ports = get_query(stext, '(ansi_port_declaration (simple_identifier) @port_name)')

  if not name or not params or not ports then
    vim.notify('Failed to get query')
    return
  end

  return {
    name = name[1],
    params = params,
    ports = ports,
  }
end

local function inst_with_telescope()
  Util.telescope(inst_with_path)
end

local M = {}

M.hdl_param = nil
M.hdl_file = {}
M.hdl_module = {}
M.hdl_instance = {}

return M
