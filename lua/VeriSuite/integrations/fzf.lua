local module_cache = require('VeriSuite.core.module_cache')
local autoinst = require('VeriSuite.core.autoinst')

local M = {}

local function ensure_cache()
  if module_cache.cache.is_loaded or module_cache.cache.loading then
    return
  end
  module_cache.load_project()
end

local function wait_for_cache(on_ready, retries)
  retries = retries or 50 -- ~5s with 100ms intervals
  if module_cache.cache.is_loaded then
    on_ready()
    return
  end
  if retries <= 0 then
    vim.notify('VeriSuite cache not ready', vim.log.levels.WARN)
    on_ready()
    return
  end
  vim.defer_fn(function()
    wait_for_cache(on_ready, retries - 1)
  end, 100)
end

local function build_entries()
  ensure_cache()
  local entries = {}
  for _, name in ipairs(module_cache.get_module_names()) do
    local info = module_cache.get_module_info(name)
    if info and info.ports and #info.ports > 0 then
      local file = info.file and vim.fn.fnamemodify(info.file, ':t') or ''
      local ports = #info.ports
      table.insert(entries, string.format('%s\t%s (%d ports)', name, file, ports))
    end
  end
  return entries
end

local function parse_line(line)
  local mod = line:match('^([^\t]+)')
  return mod
end

function M.pick_module()
  local ok, fzf = pcall(require, 'fzf-lua')
  if not ok then
    vim.notify('fzf-lua not found for VeriSuite', vim.log.levels.WARN)
    return
  end

  ensure_cache()

  wait_for_cache(function()
    local entries = build_entries()
    if #entries == 0 then
      vim.notify('No modules found in cache', vim.log.levels.WARN)
      return
    end

    fzf.fzf_exec(entries, {
      prompt = 'VeriSuite modules> ',
      actions = {
        ['default'] = function(selected)
          local line = selected[1]
          if not line then
            return
          end
          local mod = parse_line(line)
          if not mod or mod == '' then
            return
          end
          autoinst.insert_instance_at_line(mod)
        end,
      },
    })
  end)
end

function M.goto_module()
  local ok, fzf = pcall(require, 'fzf-lua')
  if not ok then
    vim.notify('fzf-lua not found for VeriSuite', vim.log.levels.WARN)
    return
  end

  ensure_cache()

  wait_for_cache(function()
    local entries = build_entries()
    if #entries == 0 then
      vim.notify('No modules found in cache', vim.log.levels.WARN)
      return
    end

    fzf.fzf_exec(entries, {
      prompt = 'VeriSuite modules (jump)> ',
      actions = {
        ['default'] = function(selected)
          local line = selected[1]
          if not line then
            return
          end
          local mod = parse_line(line)
          if not mod or mod == '' then
            return
          end
          local info = module_cache.get_module_info(mod)
          if info and info.file then
            vim.cmd('edit ' .. info.file)
            if info.line and info.line > 0 then
              vim.cmd(tostring(info.line) .. 'G')
              vim.cmd('normal! zz')
            else
              vim.fn.search('module\\s*' .. mod, 'w')
            end
          else
            vim.notify('Module not found in cache: ' .. mod, vim.log.levels.WARN)
          end
        end,
      },
    })
  end)
end

function M.register_command()
  vim.api.nvim_create_user_command('VeriSuiteFzfAutoInst', function()
    M.pick_module()
  end, { desc = 'VeriSuite: pick module via fzf-lua and insert instantiation' })

  vim.api.nvim_create_user_command('VeriSuiteFzfGotoModule', function()
    M.goto_module()
  end, { desc = 'VeriSuite: pick module via fzf-lua and jump to definition' })
end

return M
