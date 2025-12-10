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

## 要求

- Neovim >= 0.7
- Verible 在 PATH（或通过配置指定）
- `plenary.nvim`
- 可选：`fzf-lua`，`blink.cmp`

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
      keymaps = {
        -- 留空字符串可禁用
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

## 命令

| 命令 | 说明 |
| --- | --- |
| `:VeriSuiteAutoInst` | 手动输入模块名自动实例化 |
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

## License

MIT
