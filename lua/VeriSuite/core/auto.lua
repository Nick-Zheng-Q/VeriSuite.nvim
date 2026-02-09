local module_cache = require('VeriSuite.core.module_cache')
local autoinst = require('VeriSuite.core.autoinst')
local parser = require('VeriSuite.core.parser')
local fidget = require('VeriSuite.integrations.fidget')

local M = {}

local function debug_notify(msg)
  if vim.g.VeriSuiteDebugAuto then
    vim.notify(msg, vim.log.levels.DEBUG)
    vim.api.nvim_echo({ { msg, 'Comment' } }, true, {})
  end
end

local function warn_auto(msg)
  vim.notify(msg, vim.log.levels.WARN)
  if vim.g.VeriSuiteDebugAuto then
    vim.api.nvim_echo({ { msg, 'WarningMsg' } }, true, {})
  end
end

local auto_markers = {
  AUTOINST = 'AUTOINST',
  AUTOWIRE = 'AUTOWIRE',
  AUTOREG = 'AUTOREG',
  AUTOINOUT = 'AUTOINOUT',
  AUTOINPUT = 'AUTOINPUT',
  AUTOOUTPUT = 'AUTOOUTPUT',
  AUTOARG = 'AUTOARG',
  AUTOINSTPARAM = 'AUTOINSTPARAM',
  AUTOSENSE = 'AUTOSENSE',
  AUTORESET = 'AUTORESET',
  AUTOTIEOFF = 'AUTOTIEOFF',
  AUTOUNUSED = 'AUTOUNUSED',
  AUTOINOUTMODPORT = 'AUTOINOUTMODPORT',
  AUTOASCIIENUM = 'AUTOASCIIENUM',
}

local function get_line_indent(line)
  local indent = line:match('^%s*') or ''
  return indent
end

local function is_test_module(mod)
  return mod.ports == nil or #mod.ports == 0
end

local function find_autos(lines)
  local autos = {}
  for idx, line in ipairs(lines) do
    for key, marker in pairs(auto_markers) do
      local has_marker = line:match('/%*%s*' .. marker .. '%s*%*/') ~= nil
        or line:match('/%*%s*' .. marker .. '%s*%(') ~= nil
      if has_marker then
        local instance_module = nil
        local instance_name = nil
        if marker == auto_markers.AUTOINST or marker == auto_markers.AUTOINSTPARAM then
          local j = idx - 1
          while j >= 1 do
            local search_line = lines[j]
            local clean = search_line:gsub('/%*.-%*/', ''):gsub('//.*$', '')
            if clean:match('^%s*$') then
              j = j - 1
            else
              local m, n = clean:match('^%s*([%w_]+)%s+([%w_]+)%s*#?%s*%(')
              if m and n then
                instance_module, instance_name = m, n
                break
              end
              if clean:find(';') then
                break
              end
              j = j - 1
            end
          end
        end
        table.insert(autos, {
          line = idx,
          marker = marker,
          indent = get_line_indent(line),
          instance_module = instance_module,
          instance_name = instance_name,
          text = line,
        })
      end
    end
  end
  return autos
end

local function parse_auto_templates(lines)
  local templates = {}
  local i = 1
  while i <= #lines do
    local line = lines[i]
    local scope = line:match('^%s*/%*%s*([%w_]+)%s+AUTO_TEMPLATE%s*%(')
    if scope then
      templates[scope] = templates[scope] or {}
      i = i + 1
      while i <= #lines and not lines[i]:find('%*/') do
        local port, conn = lines[i]:match('%.([%w_]+)%s*%(%s*(.-)%s*%)%s*,?')
        if port and conn and conn ~= '' then
          templates[scope][port] = conn
        end
        i = i + 1
      end
    end
    i = i + 1
  end
  return templates
end

local function parse_modports(lines)
  local modports = {}
  local dirs = { input = true, output = true, inout = true }
  for _, line in ipairs(lines) do
    local name, body = line:match('modport%s+([%w_]+)%s*%((.-)%)%s*;')
    if name and body then
      local entry = { input = {}, output = {}, inout = {} }
      local current_dir = nil
      for token in body:gmatch('[^,]+') do
        local part = token:gsub('^%s+', ''):gsub('%s+$', '')
        local first, rest = part:match('^([%a_][%w_]*)%s*(.*)$')
        if first and dirs[first] then
          current_dir = first
          local signal = rest:match('([%a_][%w_]*)')
          if signal then
            table.insert(entry[current_dir], signal)
          end
        elseif current_dir then
          local signal = part:match('([%a_][%w_]*)')
          if signal then
            table.insert(entry[current_dir], signal)
          end
        end
      end
      modports[name] = entry
    end
  end
  return modports
end

local function parse_enum_literals(lines)
  local text = table.concat(lines, '\n')
  local literals = {}
  for body in text:gmatch('enum[^{}]-({[^}]-})') do
    local inner = body:sub(2, -2)
    for item in inner:gmatch('[^,]+') do
      local lit = item:match('([%a_][%w_]*)')
      if lit then
        table.insert(literals, lit)
      end
    end
  end
  return literals
end

local function find_enclosing_module_name(lines, line_num)
  for i = line_num, 1, -1 do
    local name = lines[i]:match('module%s+([%w_]+)')
    if name then
      return name
    end
  end
  return nil
end

local function strip_inline_comments(line)
  local no_block = line:gsub('/%*.-%*/', '')
  local no_line = no_block:gsub('//.*$', '')
  return no_line
end

local direction_keywords = {
  input = true,
  output = true,
  inout = true,
}

local decl_modifiers = {
  wire = true,
  reg = true,
  logic = true,
  signed = true,
  unsigned = true,
  var = true,
  tri = true,
  tri0 = true,
  tri1 = true,
  triand = true,
  trior = true,
  wand = true,
  wor = true,
  uwire = true,
  supply0 = true,
  supply1 = true,
  integer = true,
  time = true,
  real = true,
  realtime = true,
  bit = true,
  byte = true,
  shortint = true,
  int = true,
  longint = true,
}

local function parse_direction_decl(clean)
  local stmt = clean:gsub('%s*[,;]%s*$', '')
  stmt = stmt:gsub('%s*%)%s*$', '')
  local dir, rest = stmt:match('^%s*([%a_][%w_]*)%s+(.+)$')
  if not dir or not direction_keywords[dir] then
    return nil
  end
  local width = rest:match('%b[]')
  local names_area = rest:gsub('%b[]', ' '):gsub('=[^,;]+', ' ')
  for kw, _ in pairs(decl_modifiers) do
    names_area = names_area:gsub('%f[%a_]' .. kw .. '%f[^%w_]', ' ')
  end
  local names = {}
  for part in names_area:gmatch('[^,]+') do
    local name = part:match('([%a_][%w_]*)%s*$')
    if name then
      table.insert(names, name)
    end
  end
  if #names == 0 then
    return nil
  end
  return dir, width, names
end

local function find_header_end(lines, start_idx)
  local depth = 0
  local saw_paren = false
  for i = start_idx, #lines do
    local clean = strip_inline_comments(lines[i])
    local open = select(2, clean:gsub('%(', ''))
    local close = select(2, clean:gsub('%)', ''))
    if open > 0 then
      saw_paren = true
    end
    depth = depth + open - close
    if saw_paren and depth <= 0 and clean:find(';') then
      debug_notify(string.format('AUTOARG header end at line %d', i))
      return i
    end
    if clean:match('^%s*endmodule') then
      debug_notify(string.format('AUTOARG header end (endmodule) at line %d', i))
      return i
    end
  end
  debug_notify(string.format('AUTOARG header end fallback to line %d', start_idx))
  return start_idx
end

local function find_module_span(lines, module_name)
  local start_i, end_i = nil, nil
  for i, line in ipairs(lines) do
    if not start_i then
      local name = line:match('^%s*module%s+([%w_]+)')
      if name == module_name then
        start_i = i
      end
    else
      if line:match('^%s*endmodule') then
        end_i = i
        break
      end
    end
  end
  return start_i or 1, end_i or #lines
end

local function collect_port_decls(lines, module_name)
  if not module_name then
    return {}
  end
  local ports = {}
  local port_map = {}
  local in_module = false
  local in_header = false
  local module_start = nil
  for i, line in ipairs(lines) do
    if not in_module then
      local name = line:match('^%s*module%s+([%w_]+)')
      if name == module_name then
        in_module = true
        in_header = true
        module_start = module_start or i
      end
    else
      if line:match('^%s*endmodule') then
        break
      end
      local clean = strip_inline_comments(line)
      if vim.g.VeriSuiteDebugAuto then
        debug_notify(string.format('AUTOARG line %d %s: %s', i, module_name, clean))
      end
      if in_header then
        local dir, width, names = parse_direction_decl(clean)
        if dir and names then
          for _, name in ipairs(names) do
            if name and not port_map[name] then
              local p = { name = name, direction = dir, width = width }
              table.insert(ports, p)
              port_map[name] = p
            end
          end
        end
        if clean:find('%)%s*;') then
          in_header = false
        end
      end
      local dir, width, names = parse_direction_decl(clean)
      if dir and names then
        debug_notify(string.format('AUTOARG scan %s: %s', module_name, clean))
        for _, name in ipairs(names) do
          if name and not port_map[name] then
            local p = { name = name, direction = dir, width = width }
            table.insert(ports, p)
            port_map[name] = p
            debug_notify(string.format('AUTOARG add %s:%s', name, dir))
          end
        end
      end
    end
  end
  if #ports > 0 then
    local names = {}
    for _, p in ipairs(ports) do
      table.insert(names, string.format('%s:%s', p.name, p.direction or '?'))
    end
    debug_notify(string.format('AUTOARG ports for %s: %s', module_name, table.concat(names, ', ')))
  else
    debug_notify(string.format('AUTOARG ports for %s: none (module_start=%s)', module_name, tostring(module_start)))
  end
  return ports
end

local function render_port_decl(port, indent)
  local dir = port.direction or 'input'
  local width = port.width and (' ' .. port.width) or ''
  return string.format('%s%s %s %s', indent, dir, width, port.name)
end

local function render_param_decl(param, indent)
  local name = param.name or 'PARAM'
  local value = param.value or '0'
  local kind = param.type or 'parameter'
  return string.format('%s%s %s = %s', indent, kind, name, value)
end

local function format_width(width)
  if not width or width == '' or width == '1' then
    return ''
  end
  if tostring(width):find('%[') then
    return width .. ' '
  end
  return width .. ' '
end

local function render_autodecl_by_dir(mod, indent, declared, dir)
  local lines = {}
  if not mod.ports then
    return lines
  end
  local declared_set = declared or {}
  for _, p in ipairs(mod.ports) do
    if p.direction == dir and not declared_set[p.name] then
      local w = format_width(p.width)
      table.insert(lines, string.format('%s%s %s%s;', indent, dir, w, p.name))
    end
  end
  return lines
end

local function normalize_connection_signal(expr)
  if not expr then
    return nil
  end
  local s = expr:gsub('^%s+', ''):gsub('%s+$', '')
  if s == '' then
    return nil
  end
  if s:match('^[%a_][%w_]*$') then
    return s
  end
  local base = s:match('^([%a_][%w_]*)%s*%b[]$')
  if base then
    return base
  end
  return nil
end

local function render_autowire(mod, indent, module_map, declared, instance_connections)
  local lines = {}
  local declared_set = declared or {}
  local function already(name)
    return declared_set[name] == true
  end
  local wires = {}

  -- Generate wires for outputs/inouts of child instances
  if mod.instances then
    for _, inst in ipairs(mod.instances) do
      if inst.module_name then
        local child = module_map and module_map[inst.module_name] or nil
        local conn_map = (instance_connections and inst.instance_name and instance_connections[inst.instance_name]) or {}
        if child and child.ports then
          for _, p in ipairs(child.ports) do
            if p.direction == 'output' or p.direction == 'inout' then
              local target_expr = conn_map[p.name] or p.name
              local target = normalize_connection_signal(target_expr)
              if target and not already(target) then
                wires[target] = p.width or ''
              end
            end
          end
        end
      end
    end
  end

  if vim.tbl_count(wires) == 0 then
    return lines
  end

  table.insert(lines, indent .. '// Beginning of automatic wires')
  for name, width in pairs(wires) do
    local w = format_width(width)
    table.insert(lines, string.format('%swire %s%s;', indent, w, name))
  end
  table.insert(lines, indent .. '// End of automatics')
  return lines
end

local function render_autoreg(mod, indent, declared)
  local lines = {}
  if not mod.ports then
    return lines
  end
  local declared_set = declared or {}
  table.insert(lines, indent .. '// Beginning of automatic regs')
  for _, p in ipairs(mod.ports) do
    if p.direction == 'output' then
      if not declared_set[p.name] then
        table.insert(lines, string.format('%sreg %s;', indent, p.name))
      end
    end
  end
  table.insert(lines, indent .. '// End of automatics')
  return lines
end

local function render_autoinput(mod, indent, declared)
  return render_autodecl_by_dir(mod, indent, declared, 'input')
end

local function render_autooutput(mod, indent, declared)
  return render_autodecl_by_dir(mod, indent, declared, 'output')
end

local function render_autoarg(mod, indent)
  local lines = {}
  if not mod.ports then
    return lines
  end
  for i, p in ipairs(mod.ports) do
    local sep = (i == #mod.ports) and '' or ','
    table.insert(lines, string.format('%s%s%s', indent, p.name, sep))
  end
  return lines
end

local function apply_template_connection(port, template_conn, instance_name)
  if not template_conn or template_conn == '' then
    return port.name
  end

  local conn = template_conn
  local idx = tostring(instance_name or ''):match('(%d+)') or '0'
  conn = conn:gsub('@', idx)

  local width = port.width
  if width and width ~= '' and width ~= '1' then
    conn = conn:gsub('%[%]', width)
  else
    conn = conn:gsub('%[%]', '')
  end

  return conn
end

local function render_autoinst(mod, indent, ctx)
  local lines = {}
  if not mod.ports then
    return lines
  end
  ctx = ctx or {}
  local module_templates = {}
  local conn_map = {}
  if ctx.instance_connections and ctx.instance_name and ctx.instance_connections[ctx.instance_name] then
    conn_map = ctx.instance_connections[ctx.instance_name]
  end
  if ctx.templates and ctx.instance_name and ctx.templates[ctx.instance_name] then
    module_templates = ctx.templates[ctx.instance_name]
  elseif ctx.templates and mod.name and ctx.templates[mod.name] then
    module_templates = ctx.templates[mod.name]
  end
  local emit_ports = {}
  for i, port in ipairs(mod.ports) do
    if not conn_map[port.name] then
      table.insert(emit_ports, port)
    end
  end
  for i, port in ipairs(emit_ports) do
    local separator = (i == #emit_ports) and '' or ','
    local wire_name = apply_template_connection(port, module_templates[port.name], ctx.instance_name)
    table.insert(lines, string.format('%s.%s(%s)%s', indent, port.name, wire_name, separator))
  end
  return lines
end

local function render_autoinstparam(mod, indent)
  local lines = {}
  if not mod.parameters or #mod.parameters == 0 then
    return lines
  end
  for i, p in ipairs(mod.parameters) do
    local sep = (i == #mod.parameters) and '' or ','
    local val = p.value or p.name or '0'
    table.insert(lines, string.format('%s.%s(%s)%s', indent, p.name or 'PARAM', val, sep))
  end
  return lines
end

local function render_autosense(mod, indent)
  local names = {}
  if mod and mod.ports then
    for _, p in ipairs(mod.ports) do
      if p.direction == 'input' then
        table.insert(names, p.name)
      end
    end
  end
  table.sort(names)
  if #names == 0 then
    return {}
  end
  return { string.format('%s%s', indent, table.concat(names, ' or ')) }
end

local function render_autoreset(mod, indent)
  local lines = {}
  if mod and mod.ports then
    for _, p in ipairs(mod.ports) do
      if p.direction == 'output' then
        table.insert(lines, string.format('%s%s <= \'0;', indent, p.name))
      end
    end
  end
  return lines
end

local function get_always_block_bounds(lines, marker_line)
  local start_line = nil
  for i = marker_line, #lines do
    if lines[i]:match('^%s*always%b()%s*begin') or lines[i]:match('^%s*always%s*@') then
      start_line = i
      break
    end
  end
  if not start_line then
    return nil, nil
  end

  local begin_depth = 0
  local seen_begin = false
  for i = start_line, #lines do
    local clean = strip_inline_comments(lines[i])
    local b = select(2, clean:gsub('%f[%a]begin%f[^%w_]', ''))
    local e = select(2, clean:gsub('%f[%a]end%f[^%w_]', ''))
    if b > 0 then
      seen_begin = true
      begin_depth = begin_depth + b
    end
    if e > 0 then
      begin_depth = begin_depth - e
      if seen_begin and begin_depth <= 0 then
        return start_line, i
      end
    end
    if not seen_begin and clean:find(';') then
      return start_line, i
    end
  end

  return start_line, #lines
end

local function extract_identifier_set(expr)
  local ids = {}
  if not expr then
    return ids
  end
  local sanitized = expr
  sanitized = sanitized:gsub("'.", ' ')
  sanitized = sanitized:gsub('"[^"]*"', ' ')
  for id in sanitized:gmatch('([%a_][%w_]*)') do
    ids[id] = true
  end
  return ids
end

local function capture_assignment(clean, op)
  local lhs, rhs = clean:match('([%a_][%w_]*)%s*%b[]%s*' .. op .. '%s*(.-)%s*;')
  if lhs and rhs then
    return lhs, rhs
  end
  return clean:match('([%a_][%w_]*)%s*' .. op .. '%s*(.-)%s*;')
end

local reserved_words = {
  ['if'] = true,
  ['else'] = true,
  begin = true,
  ['end'] = true,
  case = true,
  endcase = true,
  ['for'] = true,
  ['while'] = true,
  ['repeat'] = true,
  always = true,
  assign = true,
  posedge = true,
  negedge = true,
  ['and'] = true,
  ['or'] = true,
  ['not'] = true,
}

local function collect_autosense_inputs(lines, marker_line, mod)
  local start_line, end_line = get_always_block_bounds(lines, marker_line)
  if not start_line then
    return nil
  end

  local input_set = {}
  if mod and mod.ports then
    for _, p in ipairs(mod.ports) do
      if p.direction == 'input' then
        input_set[p.name] = true
      end
    end
  end

  local lhs_set = {}
  local rhs_set = {}

  for i = start_line, end_line do
    local clean = strip_inline_comments(lines[i])
    local lhs_nb, rhs_nb = capture_assignment(clean, '<=')
    if lhs_nb and rhs_nb then
      lhs_set[lhs_nb] = true
      local ids = extract_identifier_set(rhs_nb)
      for id, _ in pairs(ids) do
        rhs_set[id] = true
      end
    end
    local lhs_b, rhs_b = capture_assignment(clean, '=')
    if lhs_b and rhs_b then
      lhs_set[lhs_b] = true
      local ids = extract_identifier_set(rhs_b)
      for id, _ in pairs(ids) do
        rhs_set[id] = true
      end
    end
    local cond = clean:match('%f[%a]if%f[^%w_]%s*%((.-)%)')
    if cond then
      local ids = extract_identifier_set(cond)
      for id, _ in pairs(ids) do
        rhs_set[id] = true
      end
    end
    local case_expr = clean:match('%f[%a]case%f[^%w_]%s*%((.-)%)')
    if case_expr then
      local ids = extract_identifier_set(case_expr)
      for id, _ in pairs(ids) do
        rhs_set[id] = true
      end
    end
  end

  local out = {}
  for id, _ in pairs(rhs_set) do
    if not lhs_set[id] and not reserved_words[id] and (next(input_set) == nil or input_set[id]) then
      table.insert(out, id)
    end
  end
  table.sort(out)
  return out
end

local function collect_autoreset_targets(lines, marker_line)
  local start_line, end_line = get_always_block_bounds(lines, marker_line)
  if not start_line then
    return nil
  end
  local targets = {}
  local seen = {}
  for i = start_line, end_line do
    local clean = strip_inline_comments(lines[i])
    local lhs = select(1, capture_assignment(clean, '<='))
    if lhs and not seen[lhs] then
      table.insert(targets, lhs)
      seen[lhs] = true
    end
  end
  return targets
end

local function render_autotieoff(mod, indent)
  local lines = {}
  if mod and mod.ports then
    for _, p in ipairs(mod.ports) do
      if p.direction == 'output' then
        table.insert(lines, string.format('%sassign %s = \'0;', indent, p.name))
      end
    end
  end
  return lines
end

local non_usage_line_heads = {
  module = true,
  endmodule = true,
  input = true,
  output = true,
  inout = true,
  wire = true,
  reg = true,
  logic = true,
  parameter = true,
  localparam = true,
  typedef = true,
  ['function'] = true,
  endfunction = true,
  task = true,
  endtask = true,
}

local function collect_used_identifiers(lines, module_name)
  local used = {}
  if not lines or not module_name then
    return used
  end
  local s, e = find_module_span(lines, module_name)
  for i = s, e do
    local clean = strip_inline_comments(lines[i])
    if not clean:find('AUTOUNUSED') then
      local first = clean:match('^%s*([%a_][%w_]*)')
      if not first or not non_usage_line_heads[first] then
        for id in clean:gmatch('([%a_][%w_]*)') do
          if not reserved_words[id] then
            used[id] = true
          end
        end
      end
    end
  end
  return used
end

local function render_autounused(mod, indent, ctx)
  local names = {}
  local used = collect_used_identifiers((ctx or {}).lines, (ctx or {}).module_name)
  if mod and mod.ports then
    for _, p in ipairs(mod.ports) do
      if p.direction == 'input' and not used[p.name] then
        table.insert(names, p.name)
      end
    end
  end
  table.sort(names)
  if #names == 0 then
    return {}
  end
  return { string.format('%slocalparam _unused_ok = &{%s};', indent, table.concat(names, ', ')) }
end

local function render_autoinoutmodport(indent, ctx)
  local out = {}
  local modport_name = ctx and ctx.modport_name or nil
  if not modport_name or not ctx or not ctx.modports or not ctx.modports[modport_name] then
    return out
  end
  local mp = ctx.modports[modport_name]
  for _, n in ipairs(mp.input or {}) do
    table.insert(out, string.format('%sinput %s;', indent, n))
  end
  for _, n in ipairs(mp.output or {}) do
    table.insert(out, string.format('%soutput %s;', indent, n))
  end
  for _, n in ipairs(mp.inout or {}) do
    table.insert(out, string.format('%sinout %s;', indent, n))
  end
  return out
end

local function render_autoasciienum(indent, ctx)
  local lines = {}
  for _, lit in ipairs((ctx and ctx.enum_literals) or {}) do
    table.insert(lines, string.format('%s// %s', indent, lit))
  end
  return lines
end

local function build_replacement(mod, marker, indent, ctx)
  if not mod then
    return {}
  end
  ctx = ctx or {}
  if marker == auto_markers.AUTOINST then
    return render_autoinst(mod, indent, ctx)
  elseif marker == auto_markers.AUTOWIRE then
    return render_autowire(mod, indent, ctx.module_map, ctx.declared or {}, ctx.instance_connections or {})
  elseif marker == auto_markers.AUTOREG then
    return render_autoreg(mod, indent, ctx.declared or {})
  elseif marker == auto_markers.AUTOINOUT then
    return render_autowire(mod, indent, ctx.module_map, ctx.declared or {})
  elseif marker == auto_markers.AUTOINPUT then
    return render_autoinput(mod, indent, ctx.declared or {})
  elseif marker == auto_markers.AUTOOUTPUT then
    return render_autooutput(mod, indent, ctx.declared or {})
  elseif marker == auto_markers.AUTOARG then
    return render_autoarg(mod, indent)
  elseif marker == auto_markers.AUTOINSTPARAM then
    return render_autoinstparam(mod, indent)
  elseif marker == auto_markers.AUTOSENSE then
    local derived = collect_autosense_inputs(ctx.lines or {}, ctx.marker_line or 1, mod)
    if derived and #derived > 0 then
      return { string.format('%s%s', indent, table.concat(derived, ' or ')) }
    end
    return render_autosense(mod, indent)
  elseif marker == auto_markers.AUTORESET then
    local targets = collect_autoreset_targets(ctx.lines or {}, ctx.marker_line or 1)
    if targets and #targets > 0 then
      local out = {}
      for _, lhs in ipairs(targets) do
        table.insert(out, string.format('%s%s <= \'0;', indent, lhs))
      end
      return out
    end
    return render_autoreset(mod, indent)
  elseif marker == auto_markers.AUTOTIEOFF then
    return render_autotieoff(mod, indent)
  elseif marker == auto_markers.AUTOUNUSED then
    return render_autounused(mod, indent, ctx)
  elseif marker == auto_markers.AUTOINOUTMODPORT then
    return render_autoinoutmodport(indent, ctx)
  elseif marker == auto_markers.AUTOASCIIENUM then
    return render_autoasciienum(indent, ctx)
  end
  return {}
end

local function collect_instance_connections(lines, module_name)
  local result = {}
  if not module_name then
    return result
  end
  local s, e = find_module_span(lines, module_name)
  local i = s
  while i <= e do
    local line = strip_inline_comments(lines[i])
    local mod_name, inst_name = line:match('^%s*([%a_][%w_]*)%s+([%a_][%w_]*)%s*#?%s*%(')
    if mod_name and inst_name then
      result[inst_name] = result[inst_name] or {}
      i = i + 1
      while i <= e do
        local cl = strip_inline_comments(lines[i])
        for port, expr in cl:gmatch('%.([%a_][%w_]*)%s*%(%s*(.-)%s*%)') do
          result[inst_name][port] = expr
        end
        if cl:find('%)%s*;') then
          break
        end
        i = i + 1
      end
    end
    i = i + 1
  end
  return result
end

local function collect_declared_names(lines, module_name)
  local declared = {}
  local keywords = {
    input = true,
    output = true,
    inout = true,
    wire = true,
    reg = true,
    logic = true,
    tri = true,
    tri0 = true,
    tri1 = true,
    triand = true,
    trior = true,
    wand = true,
    wor = true,
    uwire = true,
    supply0 = true,
    supply1 = true,
    integer = true,
    time = true,
    real = true,
    realtime = true,
    bit = true,
    byte = true,
    shortint = true,
    int = true,
    longint = true,
    signed = true,
    unsigned = true,
    var = true,
  }
  local s, e = find_module_span(lines, module_name)
  local collecting = false
  local buffer = {}
  for i = s, e do
    local clean = strip_inline_comments(lines[i])
      local first = clean:match('^%s*([%a_][%w_]*)%f[%W]')
      if first and (direction_keywords[first] or decl_modifiers[first]) then
        collecting = true
      end
    if collecting then
      table.insert(buffer, clean)
      if clean:find(';') then
        local decl = table.concat(buffer, ' ')
        buffer = {}
        collecting = false
        decl = decl:gsub('%b[]', ' ')
        decl = decl:gsub('=[^,;]+', ' ')
        for name in decl:gmatch('[%a_][%w_]*') do
          local lower = name:lower()
          if not keywords[lower] then
            declared[name] = true
          end
        end
      end
    end
  end
  return declared
end

local function build_module_map(current_file)
  -- prefer cached modules first (often have full ports), but allow current file
  -- to override when it has real ports/params.
  local map = {}
  for name, mod in pairs(module_cache.cache.modules or {}) do
    map[name] = mod
  end

  local mods = parser.parse_file(current_file)
  if mods then
    for _, m in ipairs(mods) do
      local cached = map[m.name]
      local cached_ports = cached and cached.ports or {}
      local cached_params = cached and cached.parameters or {}
      local has_ports = m.ports and #m.ports > 0
      local has_params = m.parameters and #m.parameters > 0

      if has_ports or has_params or not cached then
        -- only override cache when current file has actual info
        map[m.name] = m
      elseif cached and #cached_ports == 0 and has_ports then
        map[m.name] = m
      end
    end
  end

  -- Enrich port directions/widths by scanning the text of the current file,
  -- scoped to each module block to avoid cross-contamination.
  local ok_lines, file_lines = pcall(vim.fn.readfile, current_file)
  if ok_lines and file_lines then
    local function find_span(lines, module_name)
      local start_i, end_i = nil, nil
      for i, line in ipairs(lines) do
        if not start_i then
          local name = line:match('^%s*module%s+([%w_]+)')
          if name == module_name then
            start_i = i
          end
        else
          if line:match('^%s*endmodule') then
            end_i = i
            break
          end
        end
      end
      return start_i or 1, end_i or #lines
    end

    local function enrich_module(mod)
      mod.ports = mod.ports or {}
      local port_map = {}
      for _, p in ipairs(mod.ports) do
        port_map[p.name] = p
      end

      local s, e = find_span(file_lines, mod.name)
      for i = s, e do
        local line = file_lines[i]
        local dir, width, names = parse_direction_decl(line)
        if dir and names then
          local w = width and width:match('%[[^%]]+%]') or width
          for _, name in ipairs(names) do
            local entry = port_map[name]
            if not entry then
              entry = { name = name, direction = dir, width = w or '1' }
              table.insert(mod.ports, entry)
              port_map[name] = entry
            else
              entry.direction = entry.direction or dir
              if w and (not entry.width or entry.width == '1') then
                entry.width = w
              end
            end
          end
        end
      end
    end

    for _, m in pairs(map) do
      enrich_module(m)
    end
  end

  return map
end

local function replace_autoarg(lines, auto, port_list)
  if not port_list or #port_list == 0 then
    return
  end

  local open_idx = auto.line
  local close_idx = find_header_end(lines, open_idx)
  debug_notify(string.format('AUTOARG replace lines %d-%d', open_idx, close_idx))

  local head_prefix = auto.text:match('^(.-)%s*%(%s*/%*%s*' .. auto.marker .. '%s*%*/')
  head_prefix = head_prefix or auto.text:match('^(.-)%(') or auto.text
  local head_line = head_prefix .. '('
  local tail_line = lines[close_idx]
  local tail_suffix = tail_line:match('%)(.*)$') or ');'

  local outputs, inputs, inouts = {}, {}, {}
  for _, p in ipairs(port_list) do
    if p.direction == 'output' then
      table.insert(outputs, p.name)
    elseif p.direction == 'inout' then
      table.insert(inouts, p.name)
    else
      table.insert(inputs, p.name)
    end
  end

  local new_lines = { head_line }

  local groups = {}
  if #outputs > 0 then
    table.insert(groups, { label = 'Outputs', names = outputs })
  end
  if #inouts > 0 then
    table.insert(groups, { label = 'Inouts', names = inouts })
  end
  if #inputs > 0 then
    table.insert(groups, { label = 'Inputs', names = inputs })
  end

  local remaining = 0
  for _, g in ipairs(groups) do
    remaining = remaining + #g.names
  end

  for _, g in ipairs(groups) do
    table.insert(new_lines, string.format('%s  // %s', auto.indent, g.label))
    for _, name in ipairs(g.names) do
      remaining = remaining - 1
      local sep = remaining > 0 and ',' or ''
      table.insert(new_lines, string.format('%s  %s%s', auto.indent, name, sep))
    end
  end

  table.insert(new_lines, auto.indent .. ')' .. tail_suffix)

  for _ = close_idx, open_idx, -1 do
    table.remove(lines, open_idx)
  end
  for i = #new_lines, 1, -1 do
    table.insert(lines, open_idx, new_lines[i])
  end
end

local function replace_auto_inst_line(lines, auto, repl)
  local prefix = auto.text:match('^(.-)/%*%s*' .. auto.marker .. '%s*%*/')
  local suffix = auto.text:match('/%*%s*' .. auto.marker .. '%s*%*/(.-)$') or ''

  local new_lines = {}
  if prefix and prefix:match('%S') then
    table.insert(new_lines, prefix)
  end
  for _, r in ipairs(repl) do
    table.insert(new_lines, r)
  end
  if suffix and suffix:match('%S') then
    table.insert(new_lines, auto.indent .. suffix)
  end

  table.remove(lines, auto.line)
  for i = #new_lines, 1, -1 do
    table.insert(lines, auto.line, new_lines[i])
  end
end

local function replace_autos_in_buffer(bufnr, lines, autos)
  local current_file = vim.api.nvim_buf_get_name(bufnr)
  local module_map = build_module_map(current_file)
  local templates = parse_auto_templates(lines)
  local modports = parse_modports(lines)
  local enum_literals = parse_enum_literals(lines)
  local changed = false

  for i = #autos, 1, -1 do
    local auto = autos[i]
    local enclosing = find_enclosing_module_name(lines, auto.line)
    local mod_context = module_map[enclosing]
    local declared = collect_declared_names(lines, enclosing)
    local instance_connections = collect_instance_connections(lines, enclosing)

    if auto.marker == auto_markers.AUTOARG then
      local ports = {}
      if mod_context and mod_context.ports then
        for _, p in ipairs(mod_context.ports) do
          if (p.explicit_direction == nil or p.explicit_direction == true)
            and (p.direction == 'input' or p.direction == 'output' or p.direction == 'inout')
          then
            table.insert(ports, p)
          end
        end
      end
      if #ports == 0 then
        ports = collect_port_decls(lines, enclosing)
      end
      if #ports == 0 then
        warn_auto('AUTOARG: no port declarations found for ' .. (enclosing or 'unknown'))
      else
        replace_autoarg(lines, auto, ports)
        changed = true
      end
    else
    local target_mod = mod_context
    if auto.marker == auto_markers.AUTOINST or auto.marker == auto_markers.AUTOINSTPARAM then
      if auto.instance_module and module_map[auto.instance_module] then
        target_mod = module_map[auto.instance_module]
      end
    end

    if not target_mod then
      warn_auto('AUTO: missing module info for ' .. (enclosing or 'unknown'))
    else
      local base_indent = auto.indent .. '  '
      local repl = build_replacement(target_mod, auto.marker, base_indent, {
        module_map = module_map,
        declared = declared,
        templates = templates,
        instance_name = auto.instance_name,
        instance_connections = instance_connections,
        modports = modports,
        modport_name = auto.text:match('AUTOINOUTMODPORT%s*%(%s*([%w_]+)%s*%)'),
        enum_literals = enum_literals,
        module_name = enclosing,
        lines = lines,
        marker_line = auto.line,
      })

      if auto.marker == auto_markers.AUTOINST or auto.marker == auto_markers.AUTOINSTPARAM then
        replace_auto_inst_line(lines, auto, repl)
      else
        table.remove(lines, auto.line)
        if #repl > 0 then
          for j = #repl, 1, -1 do
            table.insert(lines, auto.line, repl[j])
          end
        end
      end
      changed = true
    end
    end
  end
  return changed
end

function M.expand_current_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local autos = find_autos(lines)
  if #autos == 0 then
    vim.notify('No AUTO markers found', vim.log.levels.INFO)
    return
  end

  -- save undo point
  vim.api.nvim_buf_set_option(bufnr, 'undolevels', vim.api.nvim_buf_get_option(bufnr, 'undolevels'))

  local progress_handle = nil
  if vim.g.VeriSuiteEnableFidget then
    progress_handle = fidget.create('VeriSuite', string.format('Expanding %d markers', #autos))
    fidget.report(progress_handle, 'Expanding', 50)
  end

  local ok = replace_autos_in_buffer(bufnr, lines, autos)
  if ok then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.notify('Expanded AUTO markers', vim.log.levels.INFO)
    if progress_handle then
      fidget.finish(progress_handle, 'Expanded AUTO markers')
    end
  else
    vim.notify('AUTO expansion made no changes (missing module info?)', vim.log.levels.WARN)
    if progress_handle then
      fidget.finish(progress_handle, 'No AUTO changes')
    end
  end
end

-- Simply undo the last AUTO expansion (delegates to native undo)
function M.undo_last()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.cmd('undo')
  vim.notify('Reverted last AUTO expansion (undo)', vim.log.levels.INFO)
end

function M.expand_markers(marker_types)
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local all_autos = find_autos(lines)
  local filtered_autos = {}
  for _, auto in ipairs(all_autos) do
    for _, marker_type in ipairs(marker_types) do
      if auto.marker == marker_type then
        table.insert(filtered_autos, auto)
        break
      end
    end
  end
  
  if #filtered_autos == 0 then
    vim.notify('No ' .. table.concat(marker_types, '/') .. ' markers found', vim.log.levels.INFO)
    return
  end
  
  vim.api.nvim_buf_set_option(bufnr, 'undolevels', vim.api.nvim_buf_get_option(bufnr, 'undolevels'))
  
  local ok = replace_autos_in_buffer(bufnr, lines, filtered_autos)
  if ok then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.notify('Expanded ' .. table.concat(marker_types, '/') .. ' markers', vim.log.levels.INFO)
  else
    vim.notify('AUTO expansion made no changes', vim.log.levels.WARN)
  end
end

return M
