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

## Requirements

- Neovim >= 0.7
- Verible tools in PATH (or provided via config)
- `plenary.nvim`
- Optional: `fzf-lua` for pickers; `blink.cmp` for completion

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
      keymaps = {
        -- set to '' to disable any mapping
        -- treeview_toggle = '<leader>vt',
        -- treeview_hw = '<leader>vh',
        -- treeview_test = '<leader>vv',
        -- treeview_close = '<leader>vq',
        -- parse_project = '<leader>vp',
        -- fzf_autoinst = '<leader>va',
        -- fzf_goto = '<leader>vg',
      },
    })
  end,
}
```

## Commands

| Command | Description |
| --- | --- |
| `:VeriSuiteAutoInst` | Auto-instantiate by module name (interactive input) |
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

## License

MIT
