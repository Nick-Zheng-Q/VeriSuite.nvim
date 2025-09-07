local verible = require('VeriSuite.core.verible')
local M = {}

-- 测试单个文件解析
function M.test_parse_file()
  -- 获取当前文件路径
  local current_file = vim.fn.expand('%:p')

  if current_file == '' or not vim.fn.filereadable(current_file) then
    vim.notify('No file open or file not readable', vim.log.levels.WARN)
    return
  end

  local modules = verible.parse_file(current_file)

  -- 显示结果
  M.show_results(modules, 'Verible Parse Results: ' .. vim.fn.fnamemodify(current_file, ':t'))
end

-- 显示结果在新窗口
function M.show_results(data, title)
  -- 转换为可读的字符串格式
  local lines = {}
  table.insert(lines, string.format('=== %s ===', title))
  table.insert(lines, string.format('Total items: %d', #data))
  table.insert(lines, '')

  for i, item in ipairs(data) do
    table.insert(lines, string.format('[%d] %s', i, item.name or 'unnamed'))
    if item.file then
      table.insert(lines, string.format('    File: %s', item.file))
    end
    if item.line then
      table.insert(lines, string.format('    Line: %d', item.line))
    end
    if item.parameters and #item.parameters > 0 then
      table.insert(lines, '    Parameters:')
      for j, param in ipairs(item.parameters) do
        table.insert(
          lines,
          string.format('      [%d] %s %s = %s', j, param.type, param.name, param.value)
        )
      end
    end
    table.insert(lines, '')
  end

  -- 创建新缓冲区显示结果
  M.create_result_window(lines, title)
end

-- 创建结果显示窗口
function M.create_result_window(lines, title)
  -- 创建新的缓冲区
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- 计算窗口大小 (使用新的API)
  local columns = vim.api.nvim_get_option_value('columns', {})
  local lines_opt = vim.api.nvim_get_option_value('lines', {})

  local width = math.min(100, columns - 4)
  local height = math.min(30, lines_opt - 4)

  -- 创建浮动窗口
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((lines_opt - height) / 2),
    col = math.floor((columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = title,
  }

  local win_id = vim.api.nvim_open_win(bufnr, true, opts)

  -- 设置缓冲区选项 (使用新的API)
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })

  -- 添加关闭映射
  vim.api.nvim_buf_set_keymap(bufnr, 'n', 'q', '<cmd>close<CR>', {
    noremap = true,
    silent = true,
    desc = 'Close window',
  })

  return win_id
end

-- 显示原始JSON输出（用于调试）
function M.test_parse_file_raw()
  local current_file = vim.fn.expand('%:p')

  if current_file == '' or not vim.fn.filereadable(current_file) then
    vim.notify('No file open or file not readable', vim.log.levels.WARN)
    return
  end

  local cmd = string.format(
    '%s --export_json --printtree %s',
    verible.tools.syntax_checker,
    vim.fn.shellescape(current_file)
  )

  local success, result = pcall(function()
    return vim.fn.system(cmd)
  end)

  if not success or vim.v.shell_error ~= 0 then
    vim.notify('Verible parsing failed', vim.log.levels.ERROR)
    return
  end

  -- 在新窗口显示原始JSON
  local bufnr = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(result, '\n')
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'json', { buf = bufnr })

  vim.api.nvim_command('vsplit')
  vim.api.nvim_win_set_buf(0, bufnr)

  vim.notify('Raw JSON output displayed', vim.log.levels.INFO)
end

-- 显示配置信息
function M.test_show_config()
  local config_lines = {
    '=== VeriSuite Debug Config ===',
    'Verible available: ' .. tostring(verible.is_available()),
    'Syntax checker: ' .. verible.tools.syntax_checker,
    'Project tool: ' .. verible.tools.project_tool,
  }
  M.create_result_window(config_lines, 'VeriSuite Config')
end

function M.test_tree_structure()
  local current_file = vim.fn.expand('%:p')

  local cmd = string.format(
    '%s --printtree --export_json %s',
    verible.tools.syntax_checker,
    vim.fn.shellescape(current_file)
  )

  local result = vim.fn.system(cmd)
  local ok, parsed = pcall(vim.fn.json_decode, result)

  if not ok or not parsed then
    print('Failed to parse JSON')
    return
  end

  -- 深度检查树结构
  local function inspect_node(node, path, depth)
    if depth > 5 then
      return
    end -- 限制递归深度

    print(string.rep('  ', depth) .. 'Path: ' .. path)
    print(string.rep('  ', depth) .. 'Type: ' .. type(node))

    if type(node) == 'table' then
      for k, v in pairs(node) do
        print(string.rep('  ', depth) .. '  ' .. tostring(k) .. ': ' .. type(v))
        if k == 'children' and type(v) == 'table' then
          print(string.rep('  ', depth) .. '  Children count: ' .. #v)
          for i, child in ipairs(v) do
            print(string.rep('  ', depth) .. '    [' .. i .. ']: ' .. type(child))
            if type(child) == 'table' then
              inspect_node(child, path .. '.children[' .. i .. ']', depth + 1)
            end
          end
        elseif type(v) == 'table' and k ~= 'children' then
          inspect_node(v, path .. '.' .. tostring(k), depth + 1)
        end
      end
    else
      print(string.rep('  ', depth) .. 'Value: ' .. tostring(node))
    end
  end

  for file_path, file_data in pairs(parsed) do
    if file_data and file_data.tree then
      print('=== Inspecting tree for ' .. file_path .. ' ===')
      inspect_node(file_data.tree, 'tree', 0)
    end
  end
end

return M
