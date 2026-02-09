-- tests/runner.lua
-- Test runner for AUTO expansion fixtures

local M = {}
local fixtures_dir = vim.fn.getcwd() .. '/tests/fixtures'

-- Read entire file contents
local function read_file(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local content = f:read('*a')
  f:close()
  return content
end

-- Write content to file
local function write_file(path, content)
  local f = io.open(path, 'w')
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

-- Run a single fixture test
function M.run_fixture(name)
  local input_path = fixtures_dir .. '/' .. name .. '.v'
  local expected_path = fixtures_dir .. '/' .. name .. '.expected.v'
  local output_path = fixtures_dir .. '/' .. name .. '.output.v'
  
  -- Check files exist
  local input = read_file(input_path)
  if not input then
    print("FAIL: Input file not found: " .. input_path)
    return false
  end
  
  local expected = read_file(expected_path)
  if not expected then
    print("FAIL: Expected file not found: " .. expected_path)
    return false
  end
  
  -- Copy input to output location
  write_file(output_path, input)
  
  -- Load the output file
  vim.cmd('edit ' .. output_path)
  
  -- Run AUTO expansion
  local ok, err = pcall(function()
    vim.cmd('VeriSuiteExpandAuto')
  end)
  
  if not ok then
    print("FAIL: " .. name .. " - Error during expansion: " .. tostring(err))
    vim.cmd('bdelete!')
    return false
  end
  
  -- Save the result
  vim.cmd('write')
  
  -- Read the output
  local output = read_file(output_path)
  if not output then
    print("FAIL: " .. name .. " - Could not read output")
    vim.cmd('bdelete!')
    return false
  end
  
  -- Compare to expected
  if output == expected then
    print("PASS: " .. name)
    vim.cmd('bdelete!')
    os.remove(output_path)
    return true
  else
    print("FAIL: " .. name .. " - Output differs from expected")
    -- Generate diff
    local diff_path = '.sisyphus/evidence/' .. name .. '.diff'
    os.execute('diff ' .. expected_path .. ' ' .. output_path .. ' > ' .. diff_path .. ' 2>&1')
    print("      Diff saved to: " .. diff_path)
    vim.cmd('bdelete!')
    return false
  end
end

-- Run all fixtures
function M.run_all()
  local fixtures = {
    'autoarg',
    'autowire',
    'autotemplate',
    'autotemplate_instance',
    'autosense',
    'autosense_deps',
    'autosense_case',
    'autoreset',
    'autoreset_targets',
    'autounused',
    'autoinoutmodport',
    'autoasciienum',
  }
  
  local passed = 0
  local failed = 0
  
  print("\n=== Running AUTO Expansion Tests ===\n")
  
  for _, name in ipairs(fixtures) do
    if M.run_fixture(name) then
      passed = passed + 1
    else
      failed = failed + 1
    end
  end
  
  print("\n=== Results ===")
  print("Passed: " .. passed)
  print("Failed: " .. failed)
  
  return failed == 0
end

return M
