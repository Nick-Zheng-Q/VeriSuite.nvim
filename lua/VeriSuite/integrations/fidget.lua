local M = {}

local function load_progress()
  local ok, progress = pcall(require, 'fidget.progress')
  if not ok then
    return nil
  end
  return progress
end

function M.create(title, message)
  local progress = load_progress()
  if not progress then
    return nil
  end

  local ok, handle = pcall(function()
    return progress.handle.create({
      title = title or 'VeriSuite',
      message = message or '',
      percentage = 0,
      lsp_client = { name = 'VeriSuite' },
    })
  end)

  if not ok then
    return nil
  end
  return handle
end

function M.report(handle, message, percentage)
  if not handle then
    return
  end
  pcall(function()
    handle:report({
      message = message,
      percentage = percentage,
    })
  end)
end

function M.finish(handle, message)
  if not handle then
    return
  end
  pcall(function()
    handle:finish(message)
  end)
end

return M
