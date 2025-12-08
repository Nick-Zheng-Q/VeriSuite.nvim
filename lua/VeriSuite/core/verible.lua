-- lua/verilog-tools/verible.lua
local ok_job, Job = pcall(require, 'plenary.job')
local verible = {}

local defaults = {
  tool_overrides = {},
  timeout_ms = 5000,
  prefer_mason_bin = true,
  extra_paths = {},
}

-- configurations
verible.tools = {
  syntax_checker = 'verible-verilog-syntax',
  linter = 'verible-verilog-lint',
  formatter = 'verible-verilog-format',
  language_server = 'verible-verilog-ls',
  project_tool = 'verible-verilog-project',
  diff_tool = 'verible-verilog-diff',
  obfuscator = 'verible-verilog-obfuscate',
  preprocessor = 'verible-verilog-preprocessor',
  kythe_extractor = 'verible-verilog-kythe-extractor',
}

verible.config = vim.deepcopy(defaults)
verible._cached_path = nil

function verible.setup(opts)
  verible.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
  verible._cached_path = nil
end

local function build_path()
  if verible._cached_path then
    return verible._cached_path
  end

  local paths = {}
  if verible.config.prefer_mason_bin then
    local ok, data_path = pcall(vim.fn.stdpath, 'data')
    if ok and data_path then
      table.insert(paths, data_path .. '/mason/bin')
    end
  end
  if verible.config.extra_paths and #verible.config.extra_paths > 0 then
    for _, p in ipairs(verible.config.extra_paths) do
      table.insert(paths, p)
    end
  end
  table.insert(paths, vim.env.PATH or '')
  verible._cached_path = table.concat(paths, ':')
  return verible._cached_path
end

function verible.env_path()
  return build_path()
end

function verible.env_table()
  return { PATH = build_path() }
end

local function with_temp_path(fn)
  local original_path = vim.env.PATH
  vim.env.PATH = build_path()
  local ok, result = pcall(fn)
  vim.env.PATH = original_path
  return ok, result
end

function verible.get_tool(tool_name)
  return verible.config.tool_overrides[tool_name] or verible.tools[tool_name]
end

function verible.run_command(tool_name, args, opts)
  local timeout = (opts and opts.timeout_ms) or verible.config.timeout_ms
  local cmd = verible.get_tool(tool_name)

  if not cmd then
    return {
      ok = false,
      code = -1,
      stdout = {},
      stderr = { 'unknown tool: ' .. tostring(tool_name) },
    }
  end

  if ok_job then
    local job = Job:new({
      command = cmd,
      args = args,
      env = { PATH = build_path() },
      enable_handlers = false,
    })

    local ok, stdout = pcall(function()
      return job:sync(timeout)
    end)

    local stderr = job.stderr_result or {}
    if type(stderr) == 'function' then
      local ok_fn, res = pcall(stderr, job)
      stderr = ok_fn and res or {}
    end

    local result = {
      ok = ok and job.code == 0,
      code = job.code or -1,
      stdout = stdout or {},
      stderr = stderr or {},
      err = ok and nil or stdout,
    }

    -- 某些环境下 Job 可能吞掉 stdout，做一次兜底
    if result.ok and (#result.stdout == 0) then
      with_temp_path(function()
        local escaped = {}
        for _, arg in ipairs(args or {}) do
          table.insert(escaped, vim.fn.shellescape(arg))
        end
        local full_cmd = vim.fn.shellescape(cmd) .. ' ' .. table.concat(escaped, ' ')
        result.stdout = vim.fn.systemlist(full_cmd)
        result.code = vim.v.shell_error
        result.ok = result.code == 0 and #result.stdout > 0
      end)
    end

    return result
  end

  -- Fallback to vim.fn.systemlist if plenary is unavailable
  local result, stderr_lines = nil, {}
  local code = 0

  with_temp_path(function()
    local escaped = {}
    for _, arg in ipairs(args or {}) do
      table.insert(escaped, vim.fn.shellescape(arg))
    end
    local full_cmd = vim.fn.shellescape(cmd) .. ' ' .. table.concat(escaped, ' ')
    result = vim.fn.systemlist(full_cmd)
    code = vim.v.shell_error
  end)

  if code ~= 0 then
    stderr_lines = result
  end

  return {
    ok = code == 0,
    code = code,
    stdout = result or {},
    stderr = stderr_lines,
  }
end

function verible.run_syntax(file_path, opts)
  return verible.run_command('syntax_checker', { '--export_json', '--printtree', file_path }, opts)
end

function verible.is_available()
  local missing_tools = {}

  with_temp_path(function()
    for tool_name, _ in pairs(verible.tools) do
      local tool_path = verible.get_tool(tool_name)
      if type(tool_path) == 'string' then
        local result = vim.fn.executable(tool_path)
        if result ~= 1 then
          table.insert(missing_tools, tool_name .. ' (' .. tool_path .. ')')
        end
      end
    end
  end)

  if #missing_tools > 0 then
    local missing_msg = 'Missing Verible tools: ' .. table.concat(missing_tools, ', ')
    vim.notify(missing_msg, vim.log.levels.WARN)
    return false
  end

  return true
end

function verible.extract_modules_from_json(json_data)
  local modules = {}

  if not json_data then
    return modules
  end

  if type(json_data) ~= 'table' then
    return modules
  end

  local success, err = pcall(function()
    for file_path, file_data in pairs(json_data) do
      if file_data and type(file_data) == 'table' then
        if file_data.tree then
          verible.extract_modules_from_tree_node(file_data.tree, file_path, modules)
        else
          print('No tree found for file:', file_path)
          print('File data keys:', vim.inspect(vim.tbl_keys(file_data)))
        end
      else
        print('Invalid file_data for:', file_path)
      end
    end
  end)

  if not success then
    print('Error in extract_modules_from_json:', err)
  end

  print('Found modules:', #modules)
  return modules
end

function verible.extract_modules_from_tree_node(node, file_path, modules)
  if not node or type(node) ~= 'table' then
    print('Skipping non-table node')
    return
  end

  if node.tag == 'kModuleDeclaration' then
    local module_info = verible.extract_module_header(node, file_path)
    if module_info then
      -- 提取模块实例化信息
      module_info.instances = verible.extract_module_instances(node)
      table.insert(modules, module_info)
    else
      print('No module info extracted')
    end
  end

  -- 详细调试子节点处理
  if node.children and type(node.children) == 'table' then
    for i = 1, #node.children do
      local child = node.children[i]

      if child and type(child) == 'table' then
        local success, err = pcall(function()
          verible.extract_modules_from_tree_node(child, file_path, modules)
        end)
        if not success then
          print('Error in recursive call:', err)
        end
      end
    end
  else
  end
end

function verible.extract_module_header(module_node, file_path)
  if not module_node or type(module_node) ~= 'table' then
    return nil
  end

  if not module_node.children or type(module_node.children) ~= 'table' then
    -- print('No valid children in module node')
    return nil
  end

  -- 提取模块行号
  local module_line = verible.extract_node_line(module_node) or 0

  -- 查找模块头
  for i = 1, #module_node.children do
    -- print('Checking module child', i)
    local child = module_node.children[i]
    -- print('Child type:', type(child))

    if child and type(child) == 'table' then
      -- print('Child tag:', child.tag or 'no tag')
      if child.tag == 'kModuleHeader' then
        -- print('Found kModuleHeader, extracting name...')
        local module_name = verible.find_module_name_in_header(child)
        if module_name then
          -- print('Module name found:', module_name)
          return {
            name = module_name,
            file = file_path,
            line = module_line,
            parameters = verible.extract_module_parameters(module_node),
            ports = verible.extract_module_ports(module_node),
          }
        end
      end
    end
  end

  -- print('No module header found')
  return nil
end

function verible.find_module_name_in_header(header_node)
  -- print('=== find_module_name_in_header ===')
  if not header_node or type(header_node) ~= 'table' then
    -- print('Invalid header_node')
    return nil
  end

  -- print('Header node children type:', type(header_node.children))
  -- print(
  --   'Header node children count:',
  --   header_node.children and #header_node.children or 'no children'
  -- )

  if not header_node.children or type(header_node.children) ~= 'table' then
    -- print('No valid children in header node')
    return nil
  end

  -- 详细遍历header的子节点
  for i = 1, #header_node.children do
    -- print('Checking header child', i)
    local child = header_node.children[i]
    -- print('Child type:', type(child))

    if child and type(child) == 'table' then
      -- print('Child is table')
      -- print('Child keys:', vim.inspect(vim.tbl_keys(child)))
      -- if child.tag then
      --   print('Child tag:', child.tag)
      -- end
      -- if child.text then
      --   print('Child text:', child.text)
      -- end

      if child.tag == 'SymbolIdentifier' and child.text then
        -- print('Found SymbolIdentifier with text:', child.text)
        return child.text
      end
    else
      -- print('Child is other type:', type(child))
    end
  end

  print('No SymbolIdentifier found in header')
  return nil
end

function verible.extract_parameter_info(param_node)
  if not param_node or type(param_node) ~= 'table' then
    return nil
  end

  local param_info = {
    name = '',
    value = '',
    type = 'localparam', -- 默认是localparam
    line = 0,
  }

  -- 递归搜索参数信息
  local function search_node(node, depth)
    if not node or type(node) ~= 'table' then
      return
    end

    -- 检查节点标签
    if node.tag == 'parameter' then
      param_info.type = 'parameter'
    elseif node.tag == 'localparam' then
      param_info.type = 'localparam'
    elseif node.tag == 'SymbolIdentifier' and node.text and param_info.name == '' then
      -- 第一个SymbolIdentifier通常是参数名
      param_info.name = node.text
    elseif node.text and node.tag and string.find(node.tag, 'Number') then
      -- 数字类型的值
      param_info.value = node.text
    end

    -- 递归搜索子节点
    if node.children and type(node.children) == 'table' then
      for i = 1, #node.children do
        local child = node.children[i]
        if child ~= nil then
          search_node(child, depth + 1)
        end
      end
    end
  end

  -- 开始搜索
  search_node(param_node, 0)

  -- 只有当有名称时才返回参数信息
  if param_info.name ~= '' then
    return param_info
  end

  return nil
end

function verible.extract_module_parameters(module_node)
  local parameters = {}

  if not module_node or type(module_node) ~= 'table' then
    return parameters
  end

  if not module_node.children or type(module_node.children) ~= 'table' then
    return parameters
  end

  for i = 1, #module_node.children do
    local child = module_node.children[i]
    if child and type(child) == 'table' and child.tag == 'kModuleItemList' then
      if child.children and type(child.children) == 'table' then
        for j = 1, #child.children do
          local item = child.children[j]
          if item and type(item) == 'table' and item.tag == 'kParamDeclaration' then
            local param_info = verible.extract_parameter_info(item)
            if param_info then
              table.insert(parameters, param_info)
            end
          end
        end
      end
    end
  end

  return parameters
end

function verible.extract_module_ports(module_node)
  local ports = {}

  if not module_node or type(module_node) ~= 'table' then
    return ports
  end

  if not module_node.children or type(module_node.children) ~= 'table' then
    return ports
  end

  for i = 1, #module_node.children do
    local child = module_node.children[i]
    if child and type(child) == 'table' then
      -- 处理第一种写法：模块内的端口声明 (input clk_i; output clk_o;)
      if child.tag == 'kModuleItemList' then
        if child.children and type(child.children) == 'table' then
          for j = 1, #child.children do
            local item = child.children[j]
            if item and type(item) == 'table' and item.tag == 'kModulePortDeclaration' then
              local port_info = verible.extract_port_info(item)
              if port_info then
                table.insert(ports, port_info)
              end
            end
          end
        end
      end

      -- 处理第二种写法：模块头中的端口声明 (input clk_i, output clk_o)
      if child.tag == 'kModuleHeader' then
        if child.children and type(child.children) == 'table' then
          for j = 1, #child.children do
            local header_child = child.children[j]
            if header_child and type(header_child) == 'table' and header_child.tag == 'kParenGroup' then
              if header_child.children and type(header_child.children) == 'table' then
                for k = 1, #header_child.children do
                  local port_item = header_child.children[k]
                  if port_item and type(port_item) == 'table' and port_item.tag == 'kPortDeclarationList' then
                    if port_item.children and type(port_item.children) == 'table' then
                      for m = 1, #port_item.children do
                        local port_decl = port_item.children[m]
                        if port_decl and type(port_decl) == 'table' and port_decl.tag == 'kPortDeclaration' then
                          local port_info = verible.extract_port_info(port_decl)
                          if port_info then
                            table.insert(ports, port_info)
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return ports
end

-- 提取端口信息
function verible.extract_port_info(port_node)
  if not port_node or type(port_node) ~= 'table' then
    return nil
  end

  local port_info = {
    name = '',
    direction = 'input', -- 默认是input
    width = '1', -- 默认宽度为1
    type = 'wire',
    line = 0,
  }

  -- 递归搜索端口信息，记录路径以区分上下文
  local function search_node(node, path)
    if not node or type(node) ~= 'table' then
      return
    end

    -- 更新路径
    local current_path = path .. (node.tag and (node.tag .. '/') or '')

    -- 检查节点标签确定方向
    if node.tag == 'input' then
      port_info.direction = 'input'
    elseif node.tag == 'output' then
      port_info.direction = 'output'
    elseif node.tag == 'inout' then
      port_info.direction = 'inout'
    -- 只在特定路径下的kUnqualifiedId中查找端口名
    elseif node.tag == 'kUnqualifiedId' and node.children and type(node.children) == 'table' then
      for _, child in ipairs(node.children) do
        if child and child.tag == 'SymbolIdentifier' and child.text and port_info.name == '' then
          -- 检查路径，确保不是在位宽表达式中的SymbolIdentifier
          local is_in_dimension_context = string.find(current_path, 'kDimensionRange') or
                                        string.find(current_path, 'kPackedDimensions') or
                                        string.find(current_path, 'kUnpackedDimensions')

          -- 只有不在位宽上下文中的SymbolIdentifier才是真正的端口名
          if not is_in_dimension_context then
            port_info.name = child.text
          end
          return
        end
      end
    end

    -- 递归搜索子节点
    if node.children and type(node.children) == 'table' then
      for i = 1, #node.children do
        local child = node.children[i]
        if child ~= nil then
          search_node(child, current_path)
          if port_info.name ~= '' then
            return  -- 找到端口名后立即返回
          end
        end
      end
    end
  end

  -- 开始搜索，记录路径
  search_node(port_node, '')

  -- 只有当有名称时才返回端口信息
  if port_info.name ~= '' then
    return port_info
  end

  return nil
end

-- 提取模块实例化信息
function verible.extract_module_instances(module_node)
  local instances = {}

  if not module_node or type(module_node) ~= 'table' then
    return instances
  end

  if not module_node.children or type(module_node.children) ~= 'table' then
    return instances
  end

  -- 递归搜索模块实例化
  local function search_for_instances(node, depth)
    if not node or type(node) ~= 'table' or depth > 30 then
      return
    end

    -- 查找实例化声明
    if node.tag == 'kInstantiationBase' then
      local instance_info = verible.extract_instance_info_from_instantiation(node)
      if instance_info then
        table.insert(instances, instance_info)
      end
    end

    -- 递归搜索子节点
    if node.children and type(node.children) == 'table' then
      for i = 1, #node.children do
        local child = node.children[i]
        if child then
          search_for_instances(child, depth + 1)
        end
      end
    end
  end

  -- 开始搜索
  search_for_instances(module_node, 0)

  return instances
end

-- 从 kInstantiationBase 提取实例信息
function verible.extract_instance_info_from_instantiation(instantiation_node)
  if not instantiation_node or type(instantiation_node) ~= 'table' then
    return nil
  end

  local instance_info = {
    module_name = '',
    instance_name = '',
  }

  if not instantiation_node.children or type(instantiation_node.children) ~= 'table' then
    return nil
  end

  -- kInstantiationBase 的结构：
  -- [0] kInstantiationType (包含模块名和参数)
  -- [1] kGateInstanceRegisterVariableList (包含实例名和端口连接)
  local instantiation_type = instantiation_node.children[1]
  local gate_instance_list = instantiation_node.children[2]

  -- 提取模块名 - 根据 JSON 结构递归查找 SymbolIdentifier
  local function find_module_name_in_type(node, depth)
    if not node or type(node) ~= 'table' or depth > 10 then
      return nil
    end

    if node.tag == 'SymbolIdentifier' and node.text then
      return node.text
    end

    if node.children and type(node.children) == 'table' then
      for i = 1, #node.children do
        local child = node.children[i]
        local result = find_module_name_in_type(child, depth + 1)
        if result then
          return result
        end
      end
    end

    return nil
  end

  if instantiation_type then
    local module_name = find_module_name_in_type(instantiation_type, 0)
    if module_name then
      instance_info.module_name = module_name
    end
  end

  -- 提取实例名
  if gate_instance_list and gate_instance_list.children and #gate_instance_list.children > 0 then
    local gate_instance = gate_instance_list.children[1]
    if gate_instance and gate_instance.children and #gate_instance_list.children > 0 then
      local unqualified_id = gate_instance.children[1]
      if unqualified_id and type(unqualified_id) == 'table' and unqualified_id.tag == 'SymbolIdentifier' and unqualified_id.text then
        instance_info.instance_name = unqualified_id.text
      end
    end
  end

  -- 只有当有模块名时才返回实例信息
  if instance_info.module_name ~= '' then
    return instance_info
  end

  return nil
end

-- 提取单个实例的信息（保留原函数以备兼容性）
function verible.extract_instance_info(instance_node)
  if not instance_node or type(instance_node) ~= 'table' then
    return nil
  end

  local instance_info = {
    module_name = '',     -- 被实例化的模块名
    instance_name = '',    -- 实例名
  }

  local symbols = {}
  local symbol_count = 0

  -- 递归搜索实例信息
  local function search_instance_node(node, depth)
    if not node or type(node) ~= 'table' or depth > 15 then
      return
    end

    -- 收集所有SymbolIdentifier
    if node.tag == 'SymbolIdentifier' and node.text then
      symbol_count = symbol_count + 1
      table.insert(symbols, node.text)
    end

    -- 递归搜索子节点
    if node.children and type(node.children) == 'table' then
      for i = 1, #node.children do
        local child = node.children[i]
        if child then
          search_instance_node(child, depth + 1)
        end
      end
    end
  end

  -- 开始搜索
  search_instance_node(instance_node, 0)

  -- 解析符号：第一个是模块名，第二个是实例名
  if symbol_count >= 2 then
    instance_info.module_name = symbols[1]
    instance_info.instance_name = symbols[2]
  elseif symbol_count >= 1 then
    instance_info.module_name = symbols[1]
  end

  -- 只有当有模块名时才返回实例信息
  if instance_info.module_name ~= '' then
    return instance_info
  end

  return nil
end

-- 从 Verible AST 节点中提取行号信息
function verible.extract_node_line(node)
  if not node or type(node) ~= 'table' then
    return nil
  end

  -- 优先尝试从节点的 start 属性获取行号
  if node.start and type(node.start) == 'table' and node.start.line then
    return node.start.line
  end

  -- 如果没有 start 信息，尝试从子节点中获取最小行号
  if node.children and type(node.children) == 'table' and #node.children > 0 then
    local min_line = math.huge
    for _, child in ipairs(node.children) do
      local child_line = verible.extract_node_line(child)
      if child_line and child_line < min_line then
        min_line = child_line
      end
    end
    if min_line ~= math.huge then
      return min_line
    end
  end

  return nil
end

return verible
