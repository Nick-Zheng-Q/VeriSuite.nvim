local autogen = require('VeriSuite.core.autoinst')
local verible_test = require('VeriSuite.test.verible_test')

local M = {}

-- 手动输入模块名测试自动实例化
function M.test_manual_auto_instance()
  -- 弹出输入框让用户输入模块名
  local module_name = vim.fn.input('Enter module name to instantiate: ')

  if module_name == '' then
    vim.notify('No module name entered', vim.log.levels.WARN)
    return
  end

  -- 生成实例化代码
  local lines = autogen.auto_instance_by_name(module_name)

  if not lines then
    vim.notify('Failed to generate instance for module: ' .. module_name, vim.log.levels.ERROR)
    return
  end

  -- 显示生成的代码
  M.show_instance_result(lines, module_name)
end

-- 显示实例化结果
function M.show_instance_result(lines, module_name)
  local result_lines = {
    '=== Auto Instance Result ===',
    'Module: ' .. module_name,
    'Generated ' .. #lines .. ' lines:',
    '',
  }

  -- 添加生成的代码
  for _, line in ipairs(lines) do
    table.insert(result_lines, line)
  end

  table.insert(result_lines, '')
  table.insert(result_lines, 'Press "i" to insert at cursor, "q" to close')

  -- 创建结果窗口
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result_lines)

  -- 计算窗口大小
  local columns = vim.api.nvim_get_option_value('columns', {})
  local lines_opt = vim.api.nvim_get_option_value('lines', {})

  local width = math.min(80, columns - 4)
  local height = math.min(#lines + 8, lines_opt - 4)

  -- 创建浮动窗口
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((lines_opt - height) / 2),
    col = math.floor((columns - width) / 2),
    style = 'minimal',
    border = 'rounded',
    title = 'Auto Instance: ' .. module_name,
  }

  local win_id = vim.api.nvim_open_win(bufnr, true, opts)

  -- 设置缓冲区选项
  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
  vim.api.nvim_set_option_value('filetype', 'verilog', { buf = bufnr })

  -- 添加键盘映射
  vim.keymap.set('n', 'i', function()
    -- 关闭窗口
    vim.api.nvim_win_close(win_id, true)
    -- 插入代码到当前光标位置
    local success = autogen.insert_instance_at_line(module_name)
    if not success then
      vim.notify('Failed to insert instance', vim.log.levels.ERROR)
    end
  end, { buffer = bufnr, noremap = true, silent = true, desc = 'Insert instance' })

  vim.keymap.set('n', 'q', '<cmd>close<CR>', {
    buffer = bufnr,
    noremap = true,
    silent = true,
    desc = 'Close window',
  })
end

-- 测试缓存系统
function M.test_module_cache()
  local module_cache_ok, module_cache = pcall(require, 'VeriSuite.core.module_cache')

  if not module_cache_ok then
    vim.notify('Failed to load module cache', vim.log.levels.ERROR)
    return
  end

  -- 清除缓存
  module_cache.clear_cache()

  -- 加载项目
  vim.notify('Loading project modules...', vim.log.levels.INFO)
  module_cache.load_project()

  -- 获取所有模块名
  local module_names = module_cache.get_module_names()

  if #module_names == 0 then
    vim.notify('No modules found in project', vim.log.levels.WARN)
    return
  end

  -- 显示模块列表
  local lines = {
    '=== Project Modules ===',
    'Total modules: ' .. #module_names,
    '',
  }

  for i, name in ipairs(module_names) do
    table.insert(lines, string.format('[%d] %s', i, name))
  end

  verible_test.create_result_window(lines, 'Module Cache')
end

-- 测试直接生成代码（不插入）
function M.test_generate_only()
  local module_name = vim.fn.input('Enter module name: ')

  if module_name == '' then
    vim.notify('No module name entered', vim.log.levels.WARN)
    return
  end

  local lines = autogen.auto_instance_by_name(module_name)

  if not lines then
    vim.notify('Failed to generate instance for: ' .. module_name, vim.log.levels.ERROR)
    return
  end

  -- 打印到命令行
  vim.notify('Generated instance for ' .. module_name .. ':', vim.log.levels.INFO)
  for _, line in ipairs(lines) do
    print(line)
  end
end

return M