# VeriSuite.nvim

English | [中文](README_zh.md)

VeriSuite.nvim is a Neovim plugin that speeds up Verilog/SystemVerilog development with Verible-based parsing, auto-instantiation, caching, and quick navigation/UI helpers.

## Features

- Module parsing via Verible with async project parsing (non-blocking)
- Auto-instantiation with ANSI-style port hookups
- Module cache with dependency data (hardware vs test modules)
- Tree view side panel for dependencies / reverse dependencies (filters for hardware/test roots)
- fzf-lua picker for inserting instantiations or jumping to module definitions
- Optional blink.cmp source for module/port completion (modules insert full instantiation; ports insert `.port(sig)`)
- AUTO marker expansion with fixture-covered baseline behavior

## AUTO Support Matrix (Baseline)

Supported now:

- `AUTOINST`, `AUTOINSTPARAM`
- `AUTOARG`, `AUTOINPUT`, `AUTOOUTPUT`, `AUTOINOUT`, `AUTOWIRE`, `AUTOREG`
- `AUTO_TEMPLATE` (module-level and instance-level template scope, basic `[]` and `@` substitution)
- `AUTOSENSE`, `AUTORESET`, `AUTOTIEOFF`, `AUTOUNUSED`
- `AUTOINOUTMODPORT`, `AUTOASCIIENUM`

Commands:

- `:VeriSuiteExpandAuto` - expand all markers in current buffer
- `:VeriSuiteUndoAuto` - undo last expansion
- `:VeriSuiteAutoArg`, `:VeriSuiteAutoInput`, `:VeriSuiteAutoOutput`
- `:VeriSuiteAutoWire`, `:VeriSuiteAutoReg`, `:VeriSuiteAutoInout`

## Requirements

- Neovim >= 0.7
- Verible tools in PATH (or provided via config)
- `plenary.nvim`
- Optional: `fzf-lua` for pickers; `blink.cmp` for completion
- Optional: `fidget.nvim` for progress notifications

## Installation (lazy.nvim)

```lua
return
{
  'Nick-Zheng-Q/VeriSuite.nvim',
  name = 'VeriSuite.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('VeriSuite').setup({
      enable_debug_commands = true,
      enable_autocmds = true,
      verible = {
        -- tool_overrides = { syntax_checker = "/path/to/verible-verilog-syntax" },
        -- timeout_ms = 5000,
        -- extra_paths = { "/opt/verible/bin" },
        -- prefer_mason_bin = true,
      },
      enable_blink_source = true,
      blink = {
        -- min_keyword_length = 1,
        -- priority = 40,
      },
      enable_fzf = true,
      enable_fidget = false,
      project = {
        -- extensions = { '.v', '.sv', '.vh', '.svh' },
        -- library_directories = { 'rtl', 'ip' },
        -- library_files = { 'top.sv' },
        -- include_dirs = { 'include' },
        -- defines = { SIM = 1 },
        -- parse_preprocessor = false,
      },
      keymaps = {
        -- set to '' to disable any mapping
        -- treeview_toggle = '<leader>vt',
        -- treeview_hw = '<leader>vh',
        -- treeview_test = '<leader>vv',
        -- treeview_close = '<leader>vq',
        -- parse_project = '<leader>vp',
        -- auto_expand = '<leader>ve',
        -- auto_undo = '<leader>vu',
        -- auto_arg = '',
        -- auto_input = '',
        -- auto_output = '',
        -- auto_wire = '',
        -- auto_reg = '',
        -- auto_inout = '',
        -- fzf_autoinst = '<leader>va',
        -- fzf_goto = '<leader>vg',
        -- custom = {
        --   { lhs = '<leader>vx', rhs = '<cmd>VeriSuiteExpandAuto<cr>', desc = 'Expand AUTO' },
        --   { lhs = '<leader>vX', rhs = function() print('custom') end, mode = 'n' },
        -- },
      },
    })
  end,
}
```

## Recommended User Setup

```lua
require('VeriSuite').setup({
  enable_debug_commands = false,
  enable_autocmds = true,
  enable_fzf = true,
  enable_blink_source = true,
  enable_fidget = false,
  keymaps = {
    parse_project = '<leader>vp',
    auto_expand = '<leader>ve',
    auto_undo = '<leader>vu',
    auto_arg = '<leader>va',
    auto_input = '',
    auto_output = '',
    auto_wire = '<leader>vw',
    auto_reg = '',
    auto_inout = '',
    custom = {
      { lhs = '<leader>vA', rhs = '<cmd>VeriSuiteExpandAuto<cr>', desc = 'Expand all AUTO markers' },
      { lhs = '<leader>vU', rhs = '<cmd>VeriSuiteUndoAuto<cr>', desc = 'Undo AUTO expansion' },
    },
  },
})
```

## What Is A Fixture?

- A fixture is a fixed test input + expected output pair.
- In this repo, each feature test usually uses:
  - `tests/fixtures/<name>.v` (input)
  - `tests/fixtures/<name>.expected.v` (expected expansion)
- `tests/runner.lua` runs expansion and compares actual output to expected output.

## Commands

| Command | Description |
| --- | --- |
| `:VeriSuiteAutoInst` | Auto-instantiate by module name (interactive input) |
| `:VeriSuiteExpandAuto` | Expand all AUTO markers in current buffer |
| `:VeriSuiteUndoAuto` | Undo last AUTO expansion |
| `:VeriSuiteAutoArg` | Expand `AUTOARG` markers only |
| `:VeriSuiteAutoInput` | Expand `AUTOINPUT` markers only |
| `:VeriSuiteAutoOutput` | Expand `AUTOOUTPUT` markers only |
| `:VeriSuiteAutoWire` | Expand `AUTOWIRE` markers only |
| `:VeriSuiteAutoReg` | Expand `AUTOREG` markers only |
| `:VeriSuiteAutoInout` | Expand `AUTOINOUT` markers only |
| `:VeriSuiteParseProject` | Parse project and refresh module cache |
| `:VeriSuiteDebugParseFile` | Parse current file |
| `:VeriSuiteDebugParseProject` | Parse entire project (async) |
| `:VeriSuiteDebugParseFileRaw` | Show raw Verible JSON |
| `:VeriSuiteDebugShowConfig` | Show Verible/tool status |
| `:VeriSuiteDebugTreeStructure` | Inspect AST tree (debug) |
| `:VeriSuiteTestAutoInst` | Test auto-instantiation (preview) |
| `:VeriSuiteTestModuleCache` | Rebuild cache and show stats |
| `:VeriSuiteTestGenerateOnly` | Generate instantiation without insert |
| `:VeriSuiteDebugCacheStatus` | Cache summary (modules/deps/files) |
| `:VeriSuiteTreeViewToggle` | Toggle dependency side panel |
| `:VeriSuiteTreeViewHardware` | Panel rooted at hardware modules (has ports) |
| `:VeriSuiteTreeViewTest` | Panel rooted at test modules (no ports) |
| `:VeriSuiteTreeViewRefresh` | Reload cache and refresh panel |
| `:VeriSuiteTreeViewClose` | Close panel |
| `:VeriSuiteFzfAutoInst` | fzf-lua pick module and insert instantiation |
| `:VeriSuiteFzfGotoModule` | fzf-lua pick module and jump to definition |

## Tree View

- Left split side panel; toggle with `:VeriSuiteTreeViewToggle`.
- View modes: dependencies / reverse dependencies (toggle inside with `t`); filter by hardware/test roots via commands above.
- Keybinds inside panel: `o` expand/collapse, `<CR>` jump (keeps panel open), `gf` open file, `f` filter by module name.

## blink.cmp Integration

- Enable with `enable_blink_source = true`. No extra commands needed; source registers automatically.
- Modules completion inserts full AutoInst snippet (only modules with ports). Ports completion inserts `.port(port)` with direction/width detail.
- Honors module cache; will auto-load cache if not ready.

## fzf-lua Integration

- `:VeriSuiteFzfAutoInst`: pick a module (only with ports) and insert AutoInst at cursor.
- `:VeriSuiteFzfGotoModule`: pick a module and jump to its definition line (or search by name).

## Development & Debug

- Use debug commands above; set `enable_debug_commands = false` to hide them for daily use.
- Autocmd: on `BufWritePost` for `*.v,*.sv,*.vh,*.svh` the current file is re-parsed into cache (if enabled).

## CI/CD

- CI runs on every push and pull request via GitHub Actions: `.github/workflows/ci.yml`.
- CI installs Neovim + latest Verible, then runs fixture regression:
  `nvim --headless -u tests/minimal_init.lua -c "lua if not require('tests.runner').run_all() then vim.cmd('cquit 1') end" -c "qa!"`.
- Release workflow is tag-driven (`v*`) via `.github/workflows/release.yml` and publishes GitHub Releases automatically.

## Current Limitations

- Baseline-first behavior: outputs are stable for included fixtures, but not yet 1:1 with all Emacs Verilog-mode edge cases.
- `AUTO_TEMPLATE` currently supports baseline substitutions (`[]`, `@`) and scoped overrides; advanced expression/eval semantics are not fully implemented.
- `AUTOSENSE`/`AUTORESET` use practical heuristics over current buffer context; deeply nested macro-heavy patterns may still need manual touch-up.

## License

MIT
