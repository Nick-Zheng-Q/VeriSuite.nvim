local M = {}

M.defaults = {
  treeview_toggle = '<leader>vt',
  treeview_hw = '<leader>vh',
  treeview_test = '<leader>vv',
  treeview_close = '<leader>vq',
  parse_project = '<leader>vp',
  fzf_autoinst = '<leader>va',
  fzf_goto = '<leader>vg',
}

---Apply user keymaps (buffer-local = false)
---@param mappings table|nil
function M.apply(mappings)
  local keys = vim.tbl_deep_extend('force', M.defaults, mappings or {})

  local function map(lhs, cmd, desc)
    if not lhs or lhs == '' then
      return
    end
    vim.keymap.set('n', lhs, cmd, { desc = desc, silent = true })
  end

  map(keys.treeview_toggle, '<cmd>VeriSuiteTreeViewToggle<cr>', 'VeriSuite: TreeView toggle')
  map(keys.treeview_hw, '<cmd>VeriSuiteTreeViewHardware<cr>', 'VeriSuite: TreeView hardware')
  map(keys.treeview_test, '<cmd>VeriSuiteTreeViewTest<cr>', 'VeriSuite: TreeView test')
  map(keys.treeview_close, '<cmd>VeriSuiteTreeViewClose<cr>', 'VeriSuite: TreeView close')
  map(keys.parse_project, '<cmd>VeriSuiteDebugParseProject<cr>', 'VeriSuite: Parse project')
  map(keys.fzf_autoinst, '<cmd>VeriSuiteFzfAutoInst<cr>', 'VeriSuite: fzf autoinst')
  map(keys.fzf_goto, '<cmd>VeriSuiteFzfGotoModule<cr>', 'VeriSuite: fzf goto module')
end

return M
