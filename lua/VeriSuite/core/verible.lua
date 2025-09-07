-- lua/verilog-tools/verible.lua
local verible = {}

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
  timeout = 5000,
}

function verible.is_available()
  local mason_bin = vim.fn.stdpath('data') .. '/mason/bin'
  local original_path = vim.env.PATH

  -- 临时添加Mason路径到PATH（如果不在的话）
  if not string.find(vim.env.PATH, mason_bin, 1, true) then
    vim.env.PATH = mason_bin .. ':' .. vim.env.PATH
    print('Added Mason bin to PATH: ' .. mason_bin)
  end
  local missing_tools = {}
  for tool_name, tool_path in pairs(verible.tools) do
    -- 跳过非字符串类型的配置项（如timeout）
    if type(tool_path) == 'string' then
      local result = vim.fn.executable(tool_path)
      if result ~= 1 then
        table.insert(missing_tools, tool_name .. ' (' .. tool_path .. ')')
      end
    end
  end
  if #missing_tools > 0 then
    local missing_msg = 'Missing Verible tools: ' .. table.concat(missing_tools, ', ')
    vim.notify(missing_msg, vim.log.levels.WARN)
    print(missing_msg)
    return false
  end
  return true
end

function verible.parse_file(file_path)
  -- 使用语法检查器获取AST信息
  local cmd = string.format(
    '%s --export_json --printtree %s',
    verible.tools.syntax_checker,
    vim.fn.shellescape(file_path)
  )

  print('Executing Verible command: ' .. cmd)

  local success, result, messages = pcall(function()
    return vim.fn.system(cmd)
  end)

  if not success or vim.v.shell_error ~= 0 then
    local error_msg = string.format(
      'Verible parsing failed (exit code: %d): %s - Command: %s',
      vim.v.shell_error or 0,
      (messages or 'unknown error'),
      cmd
    )
    vim.notify(error_msg, vim.log.levels.ERROR)
    print(error_msg)
    return {}
  end

  local ok, parsed = pcall(vim.fn.json_decode, result)
  if not ok then
    local error_msg = string.format('Failed to parse Verible JSON output - Command: %s', cmd)
    vim.notify(error_msg, vim.log.levels.ERROR)
    print(error_msg)
    return {}
  end

  return verible.extract_modules_from_json(parsed)
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
            line = 0,
            parameters = verible.extract_module_parameters(module_node),
            ports = verible.extract_module_ports(),
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

  -- 查找模块ItemList中的所有parameter声明
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

function verible.parse_project(root_dir)
  -- 创建文件列表
  local file_list_path = root_dir .. '/.verible_filelist'
  local files = require('verilog-tools.parser').find_verilog_files(root_dir)

  -- 写入文件列表
  local file_list = io.open(file_list_path, 'w')
  if file_list then
    for _, file in ipairs(files) do
      file_list:write(file .. '\n')
    end
    file_list:close()
  end

  -- 执行项目分析
  local cmd = string.format(
    '%s symbol-table-defs --file_list_path=%s --export_json',
    verible.tools.project_tool,
    vim.fn.shellescape(file_list_path)
  )

  local success, result = pcall(function()
    return vim.fn.system(cmd)
  end)

  -- 清理临时文件
  os.remove(file_list_path)

  if not success or vim.v.shell_error ~= 0 then
    return {}
  end

  local ok, parsed = pcall(vim.fn.json_decode, result)
  if not ok then
    return {}
  end

  return verible.extract_modules_from_json(parsed)
end

function verible.extract_module_ports(hierarchy_data, module_name)
  local ports = {}

  if not hierarchy_data or not hierarchy_data.hierarchy then
    return ports
  end

  -- 查找指定module
  for _, module in ipairs(hierarchy_data.hierarchy) do
    if module.name == module_name then
      -- 提取端口信息
      if module.ports then
        for _, port in ipairs(module.ports) do
          table.insert(ports, {
            name = port.name,
            direction = port.direction or 'unknown',
            type = port.type or 'wire',
            width = port.width,
          })
        end
      end
      break
    end
  end

  return ports
end

return verible
