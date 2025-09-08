local M = {}

local function gen_inst(name, params, ports)
  local fmt_ptn = '.%s(%s)'
  if autoinst.fmt then
    local width = Util.get_str_maxlen(ports, params.idents) + 2
    fmt_ptn = string.rep(' ', vim.bo.shiftwidth) .. '.%-' .. width .. 's(%s)'
  end

  local inst_code = {}
  local inst_line = ''
  if #params.idents > 0 then
    table.insert(inst_code, name .. ' #(')
    for i, ident in ipairs(params.idents) do
      if i == #params.idents then
        inst_line = string.format(fmt_ptn, ident, params.consts[i])
      else
        inst_line = string.format(fmt_ptn .. ',', ident, params.consts[i])
      end
      table.insert(inst_code, inst_line)
    end
    table.insert(inst_code, string.format(') u_%s(', name))
  else
    inst_line = string.format('%s u_%s(', name, name)
    table.insert(inst_code, inst_line)
  end

  for i, port in ipairs(ports) do
    if i == #ports then
      inst_line = string.format(fmt_ptn, port, port)
    else
      inst_line = string.format(fmt_ptn .. ',', port, port)
    end
    table.insert(inst_code, inst_line)
  end
  table.insert(inst_code, ');')

  return inst_code
end

return M
