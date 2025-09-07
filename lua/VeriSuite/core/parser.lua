local verible = require('VeriSuite.core.verible')
local parser = {}

-- recognize project root dir
function parser.find_project_root()
  local current_file = vim.fn.expand('%:p')
  local current_dir = vim.fn.fnamemodify(current_file, ':h')

  -- 常见的项目根目录标识
  local root_markers = { '.git', 'Makefile', 'README' }

  -- search up
  local dir = current_dir
  while dir ~= '/' do
    for _, marker in ipairs(root_markers) do
      local marker_path = dir .. '/' .. marker
      if vim.fn.isdirectory(marker_path) == 1 or vim.fn.filereadable(marker_path) == 1 then
        return dir
      end
    end
    dir = vim.fn.fnamemodify(dir, ':h')
  end

  -- did not find root dir, return file's dir
  return current_dir
end

function parser.parse_with_verible()
  local root_dir = parser.find_project_root()

  -- 尝试项目级分析
  local success, modules = pcall(function()
    return verible.parse_project(root_dir)
  end)

  if success and modules and #modules > 0 then
    return modules
  end

  -- 回退到文件级分析
  local files = parser.find_verilog_files(root_dir)
  local all_modules = {}

  for _, file in ipairs(files) do
    local file_modules = verible.parse_file(file)
    for _, module in ipairs(file_modules) do
      table.insert(all_modules, module)
    end
  end

  return all_modules
end

return parser
