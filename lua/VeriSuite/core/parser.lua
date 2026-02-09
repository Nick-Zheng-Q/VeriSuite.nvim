local verible = require('VeriSuite.core.verible')
local ok_job, Job = pcall(require, 'plenary.job')
local parser = {}

parser.options = {
  extensions = { '.v', '.sv', '.vh', '.svh' },
  library_directories = {},
  library_files = {},
  include_dirs = {},
  defines = {},
  parse_preprocessor = false,
}

parser.preprocess_cache = {}

function parser.set_options(opts)
  parser.options = vim.tbl_deep_extend('force', parser.options, opts or {})
end

local function json_decode(str)
  if vim.json and vim.json.decode then
    return vim.json.decode(str)
  end
  return vim.fn.json_decode(str)
end

-- recognize project root dir
function parser.find_project_root()
  local current_file = vim.fn.expand('%:p')
  local current_dir = vim.fn.fnamemodify(current_file, ':h')

  -- 常见的项目根目录标识
  local root_markers = { '.git', 'Makefile', 'README' }

  -- search up
  local dir = current_dir
  while dir ~= '/' and dir ~= '' and dir ~= vim.env.HOME do
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

function parser.parse_file(file_path)
  if parser.options.parse_preprocessor then
    local ok_lines, lines = pcall(vim.fn.readfile, file_path)
    if ok_lines and lines then
      local includes = {}
      local defines = {}
      for _, line in ipairs(lines) do
        local inc = line:match('^%s*`include%s+"([^"]+)"')
        if inc then
          table.insert(includes, inc)
        end
        local key, val = line:match('^%s*`define%s+([%w_]+)%s*(.*)$')
        if key then
          defines[key] = val ~= '' and val or '1'
        end
      end
      if parser.options.defines then
        for k, v in pairs(parser.options.defines) do
          defines[k] = tostring(v)
        end
      end
      parser.preprocess_cache[file_path] = {
        includes = includes,
        defines = defines,
      }
    end
  end

  local run_result = verible.run_syntax(file_path)

  if not run_result.ok then
    local stderr_msg = table.concat(run_result.stderr or {}, '\n')
    vim.notify(
      string.format('Verible parse failed (%s): %s', tostring(run_result.code), stderr_msg),
      vim.log.levels.WARN
    )
    return {}
  end

  local output = run_result.stdout or {}
  if type(output) == 'table' then
    output = table.concat(output, '\n')
  end

  if not output or output == '' then
    local stderr_msg = table.concat(run_result.stderr or {}, '\n')
    local tool = verible.get_tool('syntax_checker')
    vim.notify(
      string.format(
        'Verible returned empty output for %s\ncmd: %s\nstderr: %s',
        file_path,
        tool,
        stderr_msg
      ),
      vim.log.levels.WARN
    )
    return {}
  end

  -- Verible might emit logs to stdout; ensure it looks like JSON before decoding
  if not tostring(output):find('{') then
    local preview = output:sub(1, 200)
    vim.notify('Unexpected Verible output (non-JSON): ' .. preview, vim.log.levels.WARN)
    return {}
  end

  local ok, parsed = pcall(json_decode, output)
  if not ok then
    local preview = tostring(output):sub(1, 200)
    vim.notify('Failed to decode Verible JSON output. Preview: ' .. preview, vim.log.levels.WARN)
    return {}
  end

  local modules = verible.extract_modules_from_json(parsed)
  if modules and #modules > 0 then
    print('Found modules: ' .. #modules)
  end
  return modules
end

function parser.parse_project(root_dir)
  local files = parser.find_verilog_files(root_dir)

  print('Found ' .. #files .. ' Verilog files')
  if #files == 0 then
    return {}
  end

  -- 使用逐个文件解析的方法（可靠且简单）
  return parser.parse_files_individually(files)
end

-- 异步逐个文件解析，避免阻塞 UI
-- opts.chunk_size: 每轮处理文件数（默认10，非 Job 方式）
-- opts.concurrency: 并行 Job 数量（默认4，需 plenary）
-- opts.on_progress(done, total)
-- opts.on_finish(modules, failed)
function parser.parse_project_async(root_dir, opts)
  opts = opts or {}
  local files = parser.find_verilog_files(root_dir)
  local total = #files
  local modules = {}
  local failed = 0

  if total == 0 then
    if opts.on_finish then
      opts.on_finish(modules, failed)
    end
    return
  end

  -- 优先使用 plenary Job 并行
  if ok_job then
    local concurrency = opts.concurrency or 4
    local running = 0
    local finished = 0
    local index = 1
    local env_tbl = verible.env_table()
    local errors = {}

    local function launch_next()
      while running < concurrency and index <= total do
        local file_path = files[index]
        index = index + 1
        running = running + 1

        local job = Job:new({
          command = verible.get_tool('syntax_checker'),
          args = { '--export_json', '--printtree', file_path },
          env = env_tbl,
          enable_handlers = true,
          enable_recording = true,
          on_exit = function(j, code)
            local stdout = j:result()
            local stderr = j:stderr_result()
            local reason = nil

            if code == 0 and stdout and #stdout > 0 then
              local joined = table.concat(stdout, '\n')
              local ok, parsed = pcall(json_decode, joined)
              if ok then
                local parsed_modules = verible.extract_modules_from_json(parsed)
                if parsed_modules and #parsed_modules > 0 then
                  for _, m in ipairs(parsed_modules) do
                    table.insert(modules, m)
                  end
                else
                  reason = 'no modules'
                end
              else
                reason = 'json_decode_failed: ' .. tostring(parsed)
              end
            else
              reason = 'empty stdout'
              if code ~= 0 then
                reason = 'exit ' .. tostring(code)
              end
            end

            if reason then
              failed = failed + 1
              local stderr_msg = stderr and table.concat(stderr, '\n') or ''
              local preview = ''
              if stdout and #stdout > 0 then
                preview = table.concat(stdout, '\n'):sub(1, 200)
              end
              table.insert(errors, {
                file = file_path,
                code = code,
                err = reason,
                stderr = stderr_msg,
                stdout_preview = preview,
              })
            end

            running = running - 1
            finished = finished + 1

            if opts.on_progress then
              vim.schedule(function()
                opts.on_progress(finished, total, stderr)
              end)
            end

            if finished >= total then
              if opts.on_finish then
                vim.schedule(function()
                  opts.on_finish(modules, failed, errors)
                end)
              end
            else
              launch_next()
            end
          end,
        })

        job:start()
      end
    end

    vim.notify(string.format('Parsing %d Verilog files (concurrency=%d)...', total, concurrency), vim.log.levels.INFO)
    launch_next()
    return
  end

  -- Fallback: 分片 defer，避免 UI 阻塞但为串行
  local chunk_size = opts.chunk_size or 10
  local index = 1
  local function step()
    local processed = 0
    while index <= total and processed < chunk_size do
      local file_path = files[index]
      local parsed = parser.parse_file(file_path)
      if parsed and #parsed > 0 then
        for _, m in ipairs(parsed) do
          table.insert(modules, m)
        end
      else
        failed = failed + 1
      end
      index = index + 1
      processed = processed + 1
    end

    if opts.on_progress then
      vim.schedule(function()
        opts.on_progress(index - 1, total)
      end)
    end

    if index <= total then
      vim.defer_fn(step, 0)
    else
      if opts.on_finish then
        vim.schedule(function()
          opts.on_finish(modules, failed)
        end)
      end
    end
  end

  vim.notify(string.format('Parsing %d Verilog files...', total), vim.log.levels.INFO)
  step()
end

-- 逐个文件解析项目中的所有文件
function parser.parse_files_individually(files)
  local all_modules = {}
  local failed_count = 0

  print('Parsing ' .. #files .. ' files individually...')

  for i, file_path in ipairs(files) do
    -- 进度提示（每10个文件或最后一个文件）
    if i % 10 == 0 or i == #files then
      print('Progress: ' .. i .. '/' .. #files .. ' files')
    end

    local modules = parser.parse_file(file_path)

    if modules and #modules > 0 then
      for _, module in ipairs(modules) do
        table.insert(all_modules, module)
      end
    else
      failed_count = failed_count + 1
    end
  end

  print('Parsed ' .. #all_modules .. ' modules from ' .. #files .. ' files')
  if failed_count > 0 then
    print('Failed to parse ' .. failed_count .. ' files')
  end

  return all_modules
end

-- 递归查找Verilog/SystemVerilog文件
function parser.find_verilog_files(root_dir)
  local files = {}
  local file_set = {}
  local extensions = parser.options.extensions or { '.v', '.sv', '.vh', '.svh' }

  local function add_file(file)
    if file ~= '' and vim.fn.filereadable(file) == 1 and not file_set[file] then
      if not string.match(file, '[#%$~]$') and not string.match(file, '%.swp$') then
        file_set[file] = true
        table.insert(files, file)
      end
    end
  end

  local function scan_dir(dir)
    for _, ext in ipairs(extensions) do
      local normalized = ext
      if normalized:sub(1, 1) == '.' then
        normalized = '*' .. normalized
      end
      local pattern = dir .. '/**/' .. normalized
      local found_files = vim.fn.glob(pattern, false, true)
      for _, file in ipairs(found_files) do
        add_file(file)
      end
    end
  end

  scan_dir(root_dir)

  for _, dir in ipairs(parser.options.library_directories or {}) do
    local abs = dir
    if vim.fn.isdirectory(abs) == 0 then
      abs = root_dir .. '/' .. dir
    end
    if vim.fn.isdirectory(abs) == 1 then
      scan_dir(abs)
    end
  end

  for _, file in ipairs(parser.options.library_files or {}) do
    local abs = file
    if vim.fn.filereadable(abs) == 0 then
      abs = root_dir .. '/' .. file
    end
    add_file(abs)
  end

  table.sort(files)
  return files
end

return parser
