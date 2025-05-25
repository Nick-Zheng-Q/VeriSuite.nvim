local M = {}

---@alias AbsPath string
---@alias RelPath string
---@enum HDL_LANG_ID
M.HDL_LANG_ID = {
  VERILOG = 'verilog',
  SYSTEMVERILOG = 'systemverilog',
}

---@enum HDL_FILE_PROJECT_TYPE
M.HDL_FILE_PROJECT_TYPE = {
  SRC = 'src',
  SIM = 'sim',
  IP = 'ip',
  LOCAL_LIB = 'local_lib',
  PRIMITIVE = 'primitive',
  UNKNOWN = 'unknown',
}

---@enum HDL_MODULE_PORT_TYPE
M.HDL_MODULE_PORT_TYPE = {
  Inout = 'inout',
  Output = 'Output',
  Input = 'Input',
  Unknown = 'Unknown',
}

---@enum HDL_MODULE_PARAM_TYPE
M.HDL_MODULE_PARAM_TYPE = {
  LocalParam = 0,
  Parameter = 1,
  Unknown = 2,
}

---@enum InstModPathStatus
M.InstModPathStatus = {
  Current = 0,
  Include = 1,
  Others = 2,
  Unknown = 3,
}
---@class position
---@field line number
---@field column number
M.position = {
  line = 0,
  column = 0,
}

---@class range
---@field start_pos position
---@field end_pos position
M.range = {
  start_pos = M.position,
  end_pos = M.position,
}

return M
