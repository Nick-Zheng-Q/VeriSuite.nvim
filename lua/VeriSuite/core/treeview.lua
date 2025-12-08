-- lua/VeriSuite/core/treeview.lua
local module_cache = require('VeriSuite.core.module_cache')
local parser = require('VeriSuite.core.parser')

local treeview = {}

-- 窗口状态
treeview.window_state = {
  win_id = nil,
  buf_id = nil,
  is_open = false,
  tree_data = {},
  expanded_nodes = {},
  view_mode = 'deps', -- 'deps' or 'rdeps'
  filter = nil,
}

-- 依赖树节点结构
local function create_tree_node(name, type, file_path, level)
  return {
    name = name,
    type = type, -- 'module', 'file', 'dependency'
    file_path = file_path,
    level = level,
    children = {},
    parent = nil,
    is_expanded = true,
    has_children = false,
    dependency_count = 0,
    dependent_count = 0,
  }
end

-- 构建模块依赖树
function treeview.build_dependency_tree(opts)
  opts = opts or {}
  local mode = opts.view_mode or treeview.window_state.view_mode or 'deps'
  local filter = opts.filter or treeview.window_state.filter

  if not module_cache.cache.is_loaded then
    return create_tree_node('Loading...', 'root', nil, 0)
  end

  local tree_root = create_tree_node(
    string.format('Project Root (%s%s)', mode == 'deps' and 'dependencies' or 'reverse', filter and (', filter=' .. filter) or ''),
    'root',
    module_cache.cache.project_root,
    0
  )

  local dependency_tree = module_cache.get_dependency_tree()

  local all_modules = {}
  for module_name, module_data in pairs(dependency_tree) do
    all_modules[module_name] = create_tree_node(module_name, 'module', module_data.file, 1)
    all_modules[module_name].dependency_count = #module_data.dependencies
    all_modules[module_name].dependent_count = #module_data.dependents
  end

  local function children_of(name)
    local data = dependency_tree[name]
    if not data then
      return {}
    end
    if mode == 'deps' then
      return data.dependencies or {}
    else
      return data.dependents or {}
    end
  end

  local root_modules = {}
  if filter and all_modules[filter] then
    root_modules = { filter }
  else
    for module_name, module_data in pairs(dependency_tree) do
      local list = mode == 'deps' and module_data.dependents or module_data.dependencies
      if #list == 0 then
        table.insert(root_modules, module_name)
      end
    end
  end

  if #root_modules == 0 then
    local min_count = math.huge
    for module_name, module_data in pairs(dependency_tree) do
      local list = mode == 'deps' and module_data.dependents or module_data.dependencies
      if #list < min_count then
        min_count = #list
        root_modules = { module_name }
      elseif #list == min_count then
        table.insert(root_modules, module_name)
      end
    end
  end

  for _, root_module_name in ipairs(root_modules) do
    local root_node = all_modules[root_module_name]
    if root_node then
      root_node.level = 1
      treeview.build_module_dependency_tree(root_node, all_modules, dependency_tree, nil, mode, children_of)
      table.insert(tree_root.children, root_node)
      root_node.parent = tree_root
    end
  end

  local visited_modules = {}
  treeview.mark_visited_modules(tree_root, visited_modules)

  for module_name, module_node in pairs(all_modules) do
    if not visited_modules[module_name] then
      module_node.level = 1
      treeview.build_module_dependency_tree(module_node, all_modules, dependency_tree, nil, mode, children_of)
      table.insert(tree_root.children, module_node)
      module_node.parent = tree_root
    end
  end

  tree_root.has_children = #tree_root.children > 0
  return tree_root
end

-- 递归构建模块依赖树
function treeview.build_module_dependency_tree(module_node, all_modules, dependency_tree, visited, mode, children_of)
  mode = mode or 'deps'
  children_of = children_of or function(name)
    local data = dependency_tree[name]
    return data and data.dependencies or {}
  end

  local child_names = children_of(module_node.name)
  if not child_names or #child_names == 0 then
    return
  end

  -- 初始化visited表（用于检测循环依赖）
  visited = visited or {}

  -- 检测循环依赖
  if visited[module_node.name] then
    return
  end
  visited[module_node.name] = true

  module_node.has_children = true

  for _, dep_name in ipairs(child_names) do
    local dep_node = all_modules[dep_name]
    if dep_node and dep_node.name ~= module_node.name then
      local new_dep_node = create_tree_node(dep_node.name, "dependency", dep_node.file_path, module_node.level + 1)
      new_dep_node.dependency_count = dep_node.dependency_count
      new_dep_node.dependent_count = dep_node.dependent_count
      new_dep_node.parent = module_node
      local new_visited = vim.deepcopy(visited)
      treeview.build_module_dependency_tree(new_dep_node, all_modules, dependency_tree, new_visited, mode, children_of)
      table.insert(module_node.children, new_dep_node)
    end
  end
end

-- 标记已访问的模块
function treeview.mark_visited_modules(tree_node, visited)
  if tree_node.type == "module" then
    visited[tree_node.name] = true
  end

  if tree_node.children then
    for _, child in ipairs(tree_node.children) do
      treeview.mark_visited_modules(child, visited)
    end
  end
end

-- 提取项目中真正的模块定义
function treeview.extract_project_modules()
  local verible = require('VeriSuite.core.verible')
  local root_dir = parser.find_project_root()
  local files = parser.find_verilog_files(root_dir)

  local project_modules = {}

  for _, file in ipairs(files) do
    local modules = treeview.extract_modules_from_file(file)
    if #modules > 0 then
      project_modules[file] = modules
    end
  end

  return project_modules
end

-- 从单个文件中提取模块定义
function treeview.extract_modules_from_file(file_path)
  local verible = require('VeriSuite.core.verible')
  local modules = {}

  -- 使用 Verible 语法分析提取模块定义
  local cmd = string.format('%s print --export_json "%s"', verible.tools.verible_syntax, file_path)
  local result = vim.fn.system(cmd)

  -- 如果 JSON 导出失败，使用简单的文本匹配
  if vim.v.shell_error ~= 0 or not result or #result < 10 then
    return treeview.extract_modules_from_text(file_path)
  end

  -- 解析 JSON 输出提取模块
  local success, data = pcall(vim.json.decode, result)
  if success and data and data.modules then
    for _, module in ipairs(data.modules) do
      if module.name and module.name ~= "" then
        table.insert(modules, module.name)
      end
    end
  else
    -- JSON 解析失败，回退到文本匹配
    modules = treeview.extract_modules_from_text(file_path)
  end

  return modules
end

-- 从文本中提取模块定义（回退方案）
function treeview.extract_modules_from_text(file_path)
  local modules = {}
  local content = vim.fn.readfile(file_path)

  for _, line in ipairs(content) do
    -- 匹配模块定义: module module_name (...);
    local module_name = string.match(line, '^%s*module%s+([%w_]+)%s*%(')
    if module_name then
      table.insert(modules, module_name)
    end

    -- 匹配简单的模块定义: module module_name;
    module_name = string.match(line, '^%s*module%s+([%w_]+)%s*;')
    if module_name then
      table.insert(modules, module_name)
    end
  end

  return modules
end

-- 构建模块间的依赖关系
function treeview.build_module_dependencies(all_modules, module_dependencies)
  -- 为每个模块添加依赖的子节点
  for file, dependencies in pairs(module_dependencies) do
    for _, dep_module_name in ipairs(dependencies) do
      local dep_module = all_modules[dep_module_name]
      if dep_module then
        -- 找到依赖这个模块的模块
        for module_name, module_node in pairs(all_modules) do
          if module_node.file_path == file and module_name ~= dep_module_name then
            -- 添加依赖关系
            local dep_node = create_tree_node(dep_module_name, "dependency", dep_module.file_path, module_node.level + 1)
            dep_node.has_children = false
            table.insert(module_node.children, dep_node)
            module_node.has_children = true
            module_node.dependency_count = module_node.dependency_count + 1
            break
          end
        end
      end
    end
  end
end


-- 计算每个模块被依赖的数量
function treeview.calculate_dependent_counts(all_modules, module_deps)
  -- 初始化被依赖计数
  for _, module in pairs(all_modules) do
    module.dependent_count = 0
  end

  -- 统计被依赖次数
  for file, modules in pairs(module_deps) do
    for _, dep_module in ipairs(modules) do
      local module_node = all_modules[dep_module]
      if module_node then
        module_node.dependent_count = module_node.dependent_count + 1
      end
    end
  end
end

-- 生成树形显示文本
function treeview.render_tree(tree_node, indent)
  indent = indent or ""
  local lines = {}

  if not tree_node then
    return lines
  end

  local prefix = ""
  local expand_indicator = ""

  if tree_node.type ~= "root" then
    if tree_node.has_children then
      expand_indicator = tree_node.is_expanded and "▼ " or "▶ "
    else
      expand_indicator = "   "
    end

    -- 添加图标和统计信息
    local icon = treeview.get_node_icon(tree_node)
    local stats = treeview.get_node_stats(tree_node)

    prefix = indent .. expand_indicator .. icon .. " " .. tree_node.name .. stats
    table.insert(lines, prefix)
  end

  -- 递归渲染子节点
  if tree_node.is_expanded and tree_node.children then
    local child_indent = tree_node.type == "root" and "" or (indent .. "  ")
    for i, child in ipairs(tree_node.children) do
      local is_last = (i == #tree_node.children)
      local child_lines = treeview.render_tree(child, child_indent .. (is_last and "└─ " or "├─ "))
      for _, line in ipairs(child_lines) do
        table.insert(lines, line)
      end
    end
  end

  return lines
end

-- 获取节点图标
function treeview.get_node_icon(node)
  local icons = {
    root = "📁",
    module = "📦",
    dependency = "🔗",
  }
  return icons[node.type] or "•"
end

-- 获取节点统计信息
function treeview.get_node_stats(node)
  if node.type == "module" then
    local deps = node.dependency_count > 0 and " (deps: " .. node.dependency_count .. ")" or ""
    local dependents = node.dependent_count > 0 and " (used by: " .. node.dependent_count .. ")" or ""
    return deps .. dependents
  elseif node.type == "dependency" then
    return " (in " .. node.dependent_count .. " trees)"
  end
  return ""
end

-- 创建侧边栏窗口
function treeview.create_sidebar()
  local width = 60
  local height = vim.o.lines - 4
  local col = vim.o.columns - width - 2

  -- 创建buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- 设置buffer选项
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'verisuite-treeview')

  -- 创建窗口
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = col,
    row = 1,
    border = 'rounded',
    style = 'minimal',
    title = ' Module Dependencies ',
    title_pos = 'center',
  })

  return win, buf
end

-- 显示依赖树
function treeview.show_dependency_tree()
  -- 如果窗口已经打开，关闭它
  if treeview.window_state.is_open then
    treeview.close_dependency_tree()
    return
  end

  treeview.window_state.view_mode = 'deps'
  treeview.window_state.filter = nil

  local function open_when_ready()
    if not module_cache.cache.is_loaded then
      if not module_cache.cache.loading then
        module_cache.load_project()
      end
      vim.defer_fn(open_when_ready, 100)
      return
    end

    local tree_data = treeview.build_dependency_tree()
    treeview.window_state.tree_data = tree_data

    local win, buf = treeview.create_sidebar()
    treeview.window_state.win_id = win
    treeview.window_state.buf_id = buf
    treeview.window_state.is_open = true
    treeview.window_state.tree_data = tree_data

    treeview.setup_keymaps(buf)
    treeview.refresh_tree()
    treeview.setup_highlighting()

    vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
      buffer = buf,
      once = true,
      callback = treeview.close_dependency_tree,
    })
  end

  open_when_ready()
end

-- 关闭依赖树
function treeview.close_dependency_tree()
  if treeview.window_state.win_id and vim.api.nvim_win_is_valid(treeview.window_state.win_id) then
    vim.api.nvim_win_close(treeview.window_state.win_id, true)
  end

  if treeview.window_state.buf_id and vim.api.nvim_buf_is_valid(treeview.window_state.buf_id) then
    vim.api.nvim_buf_delete(treeview.window_state.buf_id, { force = true })
  end

  treeview.window_state.win_id = nil
  treeview.window_state.buf_id = nil
  treeview.window_state.is_open = false
end

-- 设置键盘映射
function treeview.setup_keymaps(buf)
  local opts = { buffer = buf, silent = true, nowait = true }

  -- 跳转到模块定义行（回车键）
  vim.keymap.set('n', '<CR>', function()
    treeview.goto_module_definition()
  end, opts)

  -- 展开/折叠节点
  vim.keymap.set('n', 'o', function()
    treeview.toggle_node()
  end, opts)

  -- 刷新树
  vim.keymap.set('n', 'r', function()
    treeview.refresh_tree()
  end, opts)

  -- 跳转到文件
  vim.keymap.set('n', 'gf', function()
    treeview.goto_file()
  end, opts)

  -- 切换依赖/反向依赖视图
  vim.keymap.set('n', 't', function()
    treeview.window_state.view_mode = treeview.window_state.view_mode == 'deps' and 'rdeps' or 'deps'
    treeview.refresh_tree()
    vim.notify('Tree view: ' .. (treeview.window_state.view_mode == 'deps' and 'dependencies' or 'reverse'), vim.log.levels.INFO)
  end, opts)

  -- 按模块过滤
  vim.keymap.set('n', 'f', function()
    local input = vim.fn.input('Filter module (empty = all): ', treeview.window_state.filter or '')
    if input == '' then
      treeview.window_state.filter = nil
    else
      treeview.window_state.filter = input
    end
    treeview.refresh_tree()
  end, opts)

  -- 关闭窗口
  vim.keymap.set('n', 'q', function()
    treeview.close_dependency_tree()
  end, opts)

  vim.keymap.set('n', '<Esc>', function()
    treeview.close_dependency_tree()
  end, opts)
end

-- 设置语法高亮
function treeview.setup_highlighting()
  -- 定义高亮组
  vim.api.nvim_set_hl(0, 'VeriSuiteTreeRoot', { fg = '#61afef', bold = true })
  vim.api.nvim_set_hl(0, 'VeriSuiteTreeModule', { fg = '#98c379', bold = true })
  vim.api.nvim_set_hl(0, 'VeriSuiteTreeDependency', { fg = '#e06c75' })
  vim.api.nvim_set_hl(0, 'VeriSuiteTreeStats', { fg = '#5c6370', italic = true })
  vim.api.nvim_set_hl(0, 'VeriSuiteTreeExpanded', { fg = '#d19a66' })
  vim.api.nvim_set_hl(0, 'VeriSuiteTreeCollapsed', { fg = '#d19a66' })

  -- 应用语法匹配
  local buf = treeview.window_state.buf_id
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_call(buf, function()
      -- 根节点
      vim.fn.matchadd('VeriSuiteTreeRoot', '^.*Project Root.*')
      -- 模块节点
      vim.fn.matchadd('VeriSuiteTreeModule', '^.*📦.*')
      -- 依赖节点
      vim.fn.matchadd('VeriSuiteTreeDependency', '^.*🔗.*')
      -- 统计信息
      vim.fn.matchadd('VeriSuiteTreeStats', '\\(.*\\)$')
      -- 展开/折叠指示器
      vim.fn.matchadd('VeriSuiteTreeExpanded', '^.*▼.*')
      vim.fn.matchadd('VeriSuiteTreeCollapsed', '^.*▶.*')
    end)
  end
end

-- 切换节点展开/折叠状态
function treeview.toggle_node()
  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

  -- 查找对应的节点
  local node = treeview.find_node_by_line(treeview.window_state.tree_data, line_num)
  if node and node.has_children then
    node.is_expanded = not node.is_expanded
    treeview.refresh_tree()
  end
end

-- 根据行号查找节点
function treeview.find_node_by_line(tree_node, target_line, current_line)
  current_line = current_line or 1

  if current_line == target_line and tree_node.type ~= "root" then
    return tree_node
  end

  current_line = current_line + 1

  if tree_node.is_expanded and tree_node.children then
    for _, child in ipairs(tree_node.children) do
      local result = treeview.find_node_by_line(child, target_line, current_line)
      if result then
        return result
      end
      -- 计算子树占用的行数
      current_line = current_line + treeview.count_tree_lines(child)
    end
  end

  return nil
end

-- 计算树占用的行数
function treeview.count_tree_lines(tree_node)
  if not tree_node or tree_node.type == "root" then
    local count = 0
    if tree_node and tree_node.children then
      for _, child in ipairs(tree_node.children) do
        count = count + treeview.count_tree_lines(child)
      end
    end
    return count
  end

  local count = 1
  if tree_node.is_expanded and tree_node.children then
    for _, child in ipairs(tree_node.children) do
      count = count + treeview.count_tree_lines(child)
    end
  end
  return count
end

-- 刷新树显示
function treeview.refresh_tree()
  if not treeview.window_state.is_open then
    return
  end

  -- 重新构建树
  local tree_data = treeview.build_dependency_tree({
    view_mode = treeview.window_state.view_mode,
    filter = treeview.window_state.filter,
  })
  treeview.window_state.tree_data = tree_data

  -- 重新渲染
  local buf = treeview.window_state.buf_id
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local lines = treeview.render_tree(tree_data)
    local header = string.format(
      '[%s view]%s',
      (treeview.window_state.view_mode == 'deps' and 'dependencies' or 'reverse'),
      treeview.window_state.filter and (' filter: ' .. treeview.window_state.filter) or ''
    )
    table.insert(lines, 1, header)
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  end

  -- 重新设置高亮
  treeview.setup_highlighting()
end

-- 跳转到模块定义行
function treeview.goto_module_definition()
  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

  local node = treeview.find_node_by_line(treeview.window_state.tree_data, line_num)
  if node and (node.type == "module" or node.type == "dependency") and node.name then
    -- 从 module cache 中获取模块信息（包含行号）
    local module_cache = require('VeriSuite.core.module_cache')
    local module_info = module_cache.get_module_info(node.name)

    if module_info and module_info.file then
      treeview.close_dependency_tree()

      -- 打开文件
      vim.cmd('edit ' .. module_info.file)

      -- 跳转到模块定义行
      if module_info.line and module_info.line > 0 then
        vim.cmd('normal! ' .. module_info.line .. 'G')
        vim.cmd('normal! zz') -- 居中显示
      else
        -- 如果没有行号信息，搜索模块名
        vim.cmd('normal! gg')
        vim.fn.search('module\\s*' .. node.name, 'w')
      end
    else
      vim.notify('Module "' .. node.name .. '" not found in cache', vim.log.levels.WARN)
    end
  else
    vim.notify('Please select a module to jump to its definition', vim.log.levels.INFO)
  end
end

-- 跳转到文件
function treeview.goto_file()
  local line = vim.api.nvim_get_current_line()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

  local node = treeview.find_node_by_line(treeview.window_state.tree_data, line_num)
  if node and node.file_path then
    treeview.close_dependency_tree()
    vim.cmd('edit ' .. node.file_path)
  end
end

-- 刷新依赖分析并重新显示
function treeview.refresh_with_analysis()
  local module_cache = require('VeriSuite.core.module_cache')
  module_cache.clear_cache()
  module_cache.load_project()
  local function wait_loaded()
    if module_cache.cache.is_loaded then
      treeview.refresh_tree()
    else
      vim.defer_fn(wait_loaded, 100)
    end
  end
  wait_loaded()
end

-- 测试模块提取功能
function treeview.test_module_extraction()
  print('Testing module extraction...')

  local project_modules = treeview.extract_project_modules()
  local total_modules = 0
  local total_files = 0

  for file, modules in pairs(project_modules) do
    total_files = total_files + 1
    total_modules = total_modules + #modules
    local file_name = vim.fn.fnamemodify(file, ':t')
    print(file_name .. ': ' .. #modules .. ' modules')
    for _, module in ipairs(modules) do
      print('  - ' .. module)
    end
  end

  print('\nTotal: ' .. total_modules .. ' modules in ' .. total_files .. ' files')
end

return treeview
