# VeriSuite.nvim

中文 | [English](README.md)

VeriSuite.nvim 是一个基于 Verible 的 Verilog/SystemVerilog 开发插件，提供解析、自动实例化、缓存、依赖视图、fzf/补全集成等能力。

## 特性

- Verible 解析，项目级异步解析（不阻塞）
- 自动实例化，ANSI 风格端口连接
- 模块缓存与依赖数据（区分硬件/测试模块）
- 左侧依赖树侧栏（支持依赖/反向依赖视图，硬件/测试根过滤）
- fzf-lua 选模块插入实例化或跳转定义
- 可选 blink.cmp 补全源：模块补全插入完整实例化，端口补全插入 `.port(sig)`
- 支持 AUTO 标记扩展（基础能力已覆盖并有回归用例）

## AUTO 支持矩阵（基础版）

当前已支持：

- `AUTOINST`, `AUTOINSTPARAM`
- `AUTOARG`, `AUTOINPUT`, `AUTOOUTPUT`, `AUTOINOUT`, `AUTOWIRE`, `AUTOREG`
- `AUTO_TEMPLATE`（模块级/实例级模板作用域，基础 `[]` 与 `@` 替换）
- `AUTOSENSE`, `AUTORESET`, `AUTOTIEOFF`, `AUTOUNUSED`
- `AUTOINOUTMODPORT`, `AUTOASCIIENUM`

相关命令：

- `:VeriSuiteExpandAuto`：扩展当前缓冲区所有 AUTO 标记
- `:VeriSuiteUndoAuto`：撤销上一次扩展
- `:VeriSuiteAutoArg`, `:VeriSuiteAutoInput`, `:VeriSuiteAutoOutput`
- `:VeriSuiteAutoWire`, `:VeriSuiteAutoReg`, `:VeriSuiteAutoInout`

## 要求

- Neovim >= 0.7
- Verible 在 PATH（或通过配置指定）
- `plenary.nvim`
- 可选：`fzf-lua`，`blink.cmp`
- 可选：`fidget.nvim`（进度提示）

## 安装（lazy.nvim 示例）

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
        -- 留空字符串可禁用
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

## 推荐用户配置

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

## 什么是 Fixture？

- Fixture 就是固定的测试输入 + 期望输出。
- 在本项目里通常是一对文件：
  - `tests/fixtures/<name>.v`（输入）
  - `tests/fixtures/<name>.expected.v`（期望扩展结果）
- `tests/runner.lua` 会执行扩展并比较实际输出与期望输出，判断是否回归。

## 命令

| 命令 | 说明 |
| --- | --- |
| `:VeriSuiteAutoInst` | 手动输入模块名自动实例化 |
| `:VeriSuiteExpandAuto` | 扩展当前缓冲区全部 AUTO 标记 |
| `:VeriSuiteUndoAuto` | 撤销上一次 AUTO 扩展 |
| `:VeriSuiteAutoArg` | 仅扩展 `AUTOARG` |
| `:VeriSuiteAutoInput` | 仅扩展 `AUTOINPUT` |
| `:VeriSuiteAutoOutput` | 仅扩展 `AUTOOUTPUT` |
| `:VeriSuiteAutoWire` | 仅扩展 `AUTOWIRE` |
| `:VeriSuiteAutoReg` | 仅扩展 `AUTOREG` |
| `:VeriSuiteAutoInout` | 仅扩展 `AUTOINOUT` |
| `:VeriSuiteParseProject` | 解析项目并刷新模块缓存 |
| `:VeriSuiteDebugParseFile` | 解析当前文件 |
| `:VeriSuiteDebugParseProject` | 解析整个项目（异步） |
| `:VeriSuiteDebugParseFileRaw` | 查看 Verible 原始 JSON |
| `:VeriSuiteDebugShowConfig` | 查看 Verible/工具状态 |
| `:VeriSuiteDebugTreeStructure` | AST 调试 |
| `:VeriSuiteTestAutoInst` | 自动实例化预览 |
| `:VeriSuiteTestModuleCache` | 重建缓存并显示统计 |
| `:VeriSuiteTestGenerateOnly` | 生成实例化但不插入 |
| `:VeriSuiteDebugCacheStatus` | 缓存统计 |
| `:VeriSuiteTreeViewToggle` | 打开/关闭依赖侧栏 |
| `:VeriSuiteTreeViewHardware` | 以硬件模块为根的依赖侧栏 |
| `:VeriSuiteTreeViewTest` | 以测试模块为根（无端口） |
| `:VeriSuiteTreeViewRefresh` | 重建缓存并刷新侧栏 |
| `:VeriSuiteTreeViewClose` | 关闭侧栏 |
| `:VeriSuiteFzfAutoInst` | fzf 选模块并插入实例化 |
| `:VeriSuiteFzfGotoModule` | fzf 选模块并跳转定义 |

## 侧栏

- 左侧分屏，`Toggle` 开关；视图模式（依赖/反向）可在面板内按 `t` 切换。
- 根过滤：硬件/测试通过命令切换；面板内 `f` 按模块名过滤。
- 按键：`o` 展开/折叠，`<CR>` 跳转保持侧栏，`gf` 打开文件。

## blink.cmp 集成

- `enable_blink_source = true` 自动注册源，无需命令。
- 模块补全（有端口）插入完整 AutoInst；端口补全插入 `.port(port)`，附方向/位宽信息。
- 依赖模块缓存，未就绪时自动加载。

## fzf-lua 集成

- `:VeriSuiteFzfAutoInst`：仅有端口的模块列表，插入实例化。
- `:VeriSuiteFzfGotoModule`：跳转模块定义行（无行号时按名搜索）。

## 开发/调试

- `enable_debug_commands=false` 可屏蔽调试命令。
- 保存 Verilog/SV 文件自动增量刷新当前文件缓存（开启 enable_autocmds 时）。

## CI/CD

- 已提供 GitHub Actions CI：`.github/workflows/ci.yml`，在每次 push 和 pull request 自动执行。
- CI 会安装 Neovim 与最新 Verible，并运行 fixture 回归：
  `nvim --headless -u tests/minimal_init.lua -c "lua if not require('tests.runner').run_all() then vim.cmd('cquit 1') end" -c "qa!"`。
- 已提供基于 tag（`v*`）的发布流程：`.github/workflows/release.yml`，自动创建 GitHub Release。

## 当前限制

- 目前目标是“基础能力优先”：已覆盖核心 AUTO 流程，但尚未完全 1:1 对齐 Emacs Verilog-mode 全部边角行为。
- `AUTO_TEMPLATE` 当前实现为基础替换（`[]`、`@`）+ 作用域覆盖，高级表达式/求值语义尚未完整实现。
- `AUTOSENSE`/`AUTORESET` 基于当前缓冲区语义启发，复杂宏展开与极端嵌套场景可能仍需手工调整。

## License

MIT
