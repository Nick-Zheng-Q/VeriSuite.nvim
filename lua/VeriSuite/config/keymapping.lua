local M = {}

M.defaults = {
  treeview_toggle = '<leader>vt',
  treeview_hw = '<leader>vh',
  treeview_test = '<leader>vv',
  treeview_close = '<leader>vq',
  parse_project = '<leader>vp',
  auto_expand = '<leader>ve',
  auto_undo = '<leader>vu',
  auto_arg = '',
  auto_input = '',
  auto_output = '',
  auto_wire = '',
  auto_reg = '',
  auto_inout = '',
  fzf_autoinst = '<leader>va',
  fzf_goto = '<leader>vg',
  custom = {},
}

---Apply user keymaps (buffer-local = false)
---@param mappings table|nil
function M.apply(mappings)
  local keys = vim.tbl_deep_extend('force', M.defaults, mappings or {})

  local function map(lhs, rhs, desc, mode, extra)
    if not lhs or lhs == '' then
      return
    end
    local opts = vim.tbl_extend('force', { desc = desc, silent = true }, extra or {})
    vim.keymap.set(mode or 'n', lhs, rhs, opts)
  end

  map(keys.treeview_toggle, '<cmd>VeriSuiteTreeViewToggle<cr>', 'VeriSuite: TreeView toggle')
  map(keys.treeview_hw, '<cmd>VeriSuiteTreeViewHardware<cr>', 'VeriSuite: TreeView hardware')
  map(keys.treeview_test, '<cmd>VeriSuiteTreeViewTest<cr>', 'VeriSuite: TreeView test')
  map(keys.treeview_close, '<cmd>VeriSuiteTreeViewClose<cr>', 'VeriSuite: TreeView close')
  map(keys.parse_project, '<cmd>VeriSuiteParseProject<cr>', 'VeriSuite: Parse project')
  map(keys.auto_expand, '<cmd>VeriSuiteExpandAuto<cr>', 'VeriSuite: Expand AUTO markers')
  map(keys.auto_undo, '<cmd>VeriSuiteUndoAuto<cr>', 'VeriSuite: Undo AUTO expansion')
  map(keys.auto_arg, '<cmd>VeriSuiteAutoArg<cr>', 'VeriSuite: Expand AUTOARG')
  map(keys.auto_input, '<cmd>VeriSuiteAutoInput<cr>', 'VeriSuite: Expand AUTOINPUT')
  map(keys.auto_output, '<cmd>VeriSuiteAutoOutput<cr>', 'VeriSuite: Expand AUTOOUTPUT')
  map(keys.auto_wire, '<cmd>VeriSuiteAutoWire<cr>', 'VeriSuite: Expand AUTOWIRE')
  map(keys.auto_reg, '<cmd>VeriSuiteAutoReg<cr>', 'VeriSuite: Expand AUTOREG')
  map(keys.auto_inout, '<cmd>VeriSuiteAutoInout<cr>', 'VeriSuite: Expand AUTOINOUT')
  map(keys.fzf_autoinst, '<cmd>VeriSuiteFzfAutoInst<cr>', 'VeriSuite: fzf autoinst')
  map(keys.fzf_goto, '<cmd>VeriSuiteFzfGotoModule<cr>', 'VeriSuite: fzf goto module')

  if type(keys.custom) == 'table' then
    for _, item in ipairs(keys.custom) do
      if type(item) == 'table' and item.lhs and item.rhs then
        map(item.lhs, item.rhs, item.desc or 'VeriSuite: custom', item.mode or 'n', item.opts)
      end
    end
  end
end

return M
