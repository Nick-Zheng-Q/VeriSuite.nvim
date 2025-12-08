local verible = require('VeriSuite.core.verible')
local parser = require('VeriSuite.core.parser')

local M = {}

-- 测试单个文件解析
function M.test_parse_file()
  -- 获取当前文件路径
  local current_file = vim.fn.expand('%:p')

  if current_file == '' or not vim.fn.filereadable(current_file) then
    vim.notify('No file open or file not readable', vim.log.levels.WARN)
    return
  end

  local modules = parser.parse_file(current_file)

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
    if item.ports and #item.ports > 0 then
      table.insert(lines, '    Ports:')
      for j, port in ipairs(item.ports) do
        table.insert(
          lines,
          string.format('      [%d] %s (%s) width=%s', j, port.name, port.direction, port.width or 'N/A')
        )
      end
    else
      table.insert(lines, '    Ports: (none found)')
    end

    -- 显示实例化
    if item.instances and #item.instances > 0 then
      table.insert(lines, '    Instances:')
      for j, instance in ipairs(item.instances) do
        table.insert(
          lines,
          string.format('      [%d] %s -> %s', j, instance.instance_name or 'unnamed', instance.module_name or 'unknown')
        )
      end
    else
      table.insert(lines, '    Instances: (none found)')
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

  local result = verible.run_syntax(current_file, { timeout_ms = verible.config.timeout_ms })

  if not result.ok then
    local stderr = table.concat(result.stderr or {}, '\n')
    vim.notify('Verible parsing failed: ' .. stderr, vim.log.levels.ERROR)
    return
  end

  -- 在新窗口显示原始JSON
  local bufnr = vim.api.nvim_create_buf(false, true)
  local output = result.stdout
  if type(output) == 'table' then
    output = table.concat(output, '\n')
  end
  local lines = vim.split(output or '', '\n')
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

  -- 深度检查树结构，重点关注模块和端口相关的tag
  local function inspect_node(node, path, depth)
    if depth > 6 then
      return
    end -- 限制递归深度

    if type(node) == 'table' and node.tag then
      local tag = node.tag
      local indent = string.rep('  ', depth)

      -- 只显示重要的节点
      if string.find(tag, 'Module') or
         string.find(tag, 'Port') or
         string.find(tag, 'input') or
         string.find(tag, 'output') or
         string.find(tag, 'inout') or
         string.find(tag, 'SymbolIdentifier') or
         string.find(tag, 'Header') then
        print(indent .. path .. ' -> tag: ' .. tag)

        -- 如果有text信息，显示出来
        if node.text and node.text ~= '' then
          print(indent .. '  text: "' .. node.text .. '"')
        end

        -- 显示子节点数量
        if node.children and type(node.children) == 'table' then
          print(indent .. '  children count: ' .. #node.children)
        end
      end
    end

    if type(node) == 'table' then
      if node.children and type(node.children) == 'table' then
        for i, child in ipairs(node.children) do
          if type(child) == 'table' then
            inspect_node(child, path .. '.children[' .. i .. ']', depth + 1)
          end
        end
      end
    end
  end

  for file_path, file_data in pairs(parsed) do
    if file_data and file_data.tree then
      print('=== Inspecting tree for ' .. file_path .. ' ===')
      inspect_node(file_data.tree, 'tree', 0)
    end
  end
end

-- 测试项目解析（之前缺失的函数）
function M.test_parse_project()
  local parser = require('VeriSuite.core.parser')

  -- 获取项目根目录
  local root_dir = parser.find_project_root()
  vim.notify('Project root: ' .. root_dir, vim.log.levels.INFO)

  parser.parse_project_async(root_dir, {
    concurrency = 4,
    on_progress = function(done, total)
      if done % 20 == 0 or done == total then
        vim.notify(string.format('Parsed %d/%d files', done, total), vim.log.levels.DEBUG)
      end
    end,
    on_finish = function(modules, failed, errors)
      local msg = string.format('Project parse completed. Modules: %d, failed files: %d', #modules, failed)
      vim.schedule(function()
        vim.notify(msg, vim.log.levels.INFO)
        if errors and #errors > 0 then
          local first = errors[1]
          local detail = first.err or ''
          local preview = first.stdout_preview or ''
          local stderr = first.stderr or ''
          vim.notify(
            string.format('First failure: %s (code %s) reason: %s', first.file or 'unknown', tostring(first.code), detail),
            vim.log.levels.WARN
          )
          if preview ~= '' then
            vim.notify('stdout preview: ' .. preview, vim.log.levels.WARN)
          end
          if stderr ~= '' then
            vim.notify('stderr: ' .. stderr, vim.log.levels.WARN)
          end
        end
        M.show_results(modules, 'Project Parse Results: ' .. vim.fn.fnamemodify(root_dir, ':t'))
      end)
    end,
  })
end

return M
