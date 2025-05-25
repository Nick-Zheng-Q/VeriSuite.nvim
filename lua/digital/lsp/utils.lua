local M = {}

TS = vim.treesitter

function M.get_query(stext, query_string)
  local parser = TS.get_string_parser(stext, 'verilog')
  local ok, query = pcall(vim.treesitter.query.parse, parser:lang(), query_string)

  if not ok then
    print('Failed to parse query')
    return
  end

  local tree = parser:parse()[1]

  local items = {}
  for id, node, metadata in query:iter_captures(tree:root(), 0, 0, -1) do
    local item = vim.treesitter.get_node_text(node, stext, metadata[id])
    table.insert(items, item)
  end

  return items
end

return M
