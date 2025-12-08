<div align="center">

<h1>VeriSuite.nvim</h1>

A comprehensive Neovim plugin for Verilog/SystemVerilog development

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [Commands](#commands) • [Configuration](#configuration)

</div>

VeriSuite.nvim is a powerful Neovim plugin designed to enhance Verilog and SystemVerilog development workflow. It leverages the [Verible](https://github.com/chipsalliance/verible) tool suite to provide intelligent code parsing, module instantiation, and project management capabilities.

> [!NOTE]
> This plugin is actively under development. Core functionality is working, but many features are planned for future releases.

## Features

### ✅ Currently Implemented

- **Module Parsing**: Automatically parse Verilog/SystemVerilog files to extract module information
- **Auto-Instantiation**: Generate module instantiations with all ports and parameters
- **Module Cache**: Efficient caching system for large projects
- **Multiple Port Declaration Styles**: Support for both ANSI C and simplified ANSI C port declarations
- **Project-wide Search**: Find and parse all Verilog files in your project
- **Debug Tools**: Comprehensive debugging commands for development and troubleshooting

### 🚧 Planned Features

- Enhanced UI with floating windows
- Fuzzy finding for module selection
- SystemVerilog interface support
- Code completion integration
- Navigation and go-to-definition
- Refactoring tools
- And much more! (See [TODO list](#todo))

## Requirements

- **Neovim** >= 0.7.0
- **Verible** tool suite installed and accessible in PATH
  - `verible-verilog-syntax`
  - `verible-verilog-lint`
  - `verible-verilog-format`
  - `verible-verilog-ls`
- **Mason** (recommended for easy Verible installation)

### Installing Verible

#### Using Mason (Recommended)
```lua
require('mason').setup()
require('mason-tool-installer').setup {
  ensure_installed = {
    'verible',
  },
}
```

#### Manual Installation
```bash
# macOS
brew install verible

# Linux (Ubuntu/Debian)
wget https://github.com/chipsalliance/verible/releases/download/v0.0-3519-g5bf25af/verible-v0.0-3519-g5bf25af-linux-static-x86_64.tar.gz
tar -xzf verible-*-linux-static-x86_64.tar.gz
sudo cp verible-*/bin/* /usr/local/bin/
```

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'your-username/VeriSuite.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('VeriSuite').setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'your-username/VeriSuite.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('VeriSuite').setup()
  end,
}
```

## Usage

### Basic Workflow

1. **Open a Verilog file** in your project
2. **Parse your project** to build the module cache:
   ```vim
   :VeriSuiteDebugParseProject
   ```
3. **Generate auto-instantiation** for any module:
   ```vim
   :VeriSuiteAutoInst
   ```
   Enter the module name when prompted
4. **Insert the generated instantiation** at your cursor position

### Debug Commands

For development and troubleshooting, VeriSuite provides several debug commands:

```vim
" Parse current file and show results
:VeriSuiteDebugParseFile

" Parse entire project
:VeriSuiteDebugParseProject

" Show raw JSON output from Verible
:VeriSuiteDebugParseFileRaw

" Show configuration and tool availability
:VeriSuiteDebugShowConfig

" Inspect AST tree structure (for debugging port extraction)
:VeriSuiteDebugTreeStructure

" Test auto-instantiation with preview
:VeriSuiteTestAutoInst

" Test module cache system
:VeriSuiteTestModuleCache

" Generate code without inserting
:VeriSuiteTestGenerateOnly
```

## Commands

| Command | Description |
|---------|-------------|
| `:VeriSuiteAutoInst` | Generate module instantiation (interactive) |
| `:VeriSuiteDebugParseFile` | Parse current file and show module info |
| `:VeriSuiteDebugParseProject` | Parse entire project |
| `:VeriSuiteDebugParseFileRaw` | Show raw Verible JSON output |
| `:VeriSuiteDebugShowConfig` | Display configuration and tool status |
| `:VeriSuiteDebugTreeStructure` | Debug AST tree structure |
| `:VeriSuiteTestAutoInst` | Test auto-instantiation with preview |
| `:VeriSuiteTestModuleCache` | Test and display module cache |
| `:VeriSuiteTestGenerateOnly` | Generate code without inserting |

## Configuration

Currently, VeriSuite uses minimal configuration. Future versions will include customizable options:

```lua
require('VeriSuite').setup({
  -- set to false to avoid loading helper test commands
  enable_debug_commands = true,
  -- refresh module cache on save for *.v/*.sv/*.vh/*.svh
  enable_autocmds = true,
  -- optional Verible overrides
  verible = {
    -- tool_overrides = { syntax_checker = "/path/to/verible-verilog-syntax" },
    -- timeout_ms = 5000,
    -- extra_paths = { "/opt/verible/bin" },
    -- prefer_mason_bin = true,
  },
})
```

## Supported Verilog Features

### Port Declaration Styles

The plugin supports both major Verilog port declaration styles:

#### Style 1: ANSI C Style
```verilog
module my_module (
  input  logic clk_i,
  input  logic rst_ni,
  output logic [7:0] data_o
);
```

#### Style 2: Simplified ANSI C Style
```verilog
module my_module (clk_i, rst_ni, data_o);
  input  logic clk_i;
  input  logic rst_ni;
  output logic [7:0] data_o;
```

### Auto-Instantiation Example

Given a module like:
```verilog
module example_module (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [15:0] data_i,
  output logic [7:0]  result_o,
  output logic        valid_o
);
  // Module implementation
endmodule
```

The auto-instantiation will generate:
```verilog
example_module u_example_module (
  .clk_i    (clk_i),
  .rst_ni   (rst_ni),
  .data_i   (data_i),
  .result_o (result_o),
  .valid_o  (valid_o)
);
```

## File Structure

```
VeriSuite.nvim/
├── lua/
│   └── VeriSuite/
│       ├── core/
│       │   ├── init.lua          # Core initialization and commands
│       │   ├── verible.lua       # Verible tool integration
│       │   ├── parser.lua        # Module parsing logic
│       │   ├── autoinst.lua      # Auto-instantiation generation
│       │   └── module_cache.lua  # Module caching system
│       ├── test/
│       │   ├── init.lua          # Debug command registration
│       │   ├── verible_test.lua  # Verible parsing tests
│       │   └── autoinst_test.lua # Auto-instantiation tests
│       └── init.lua              # Main plugin entry point
├── README.md
└── ... (other config files)
```

## Development

### Running Tests

The plugin includes comprehensive debug commands for testing:

1. Open a Verilog file
2. Use the debug commands to test functionality:
   ```vim
   :VeriSuiteTestModuleCache    " Test caching system
   :VeriSuiteTestAutoInst       " Test auto-instantiation
   :VeriSuiteDebugParseFile     " Test file parsing
   ```
3. Use `<leader>pt` to quickly reload the plugin during development

### Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## TODO

See the [comprehensive TODO list](https://github.com/your-username/VeriSuite.nvim/issues) for planned features and improvements:

### High Priority
- [ ] Error handling improvements
- [ ] Module cache robustness
- [ ] Parameterized module support

### Medium Priority
- [ ] UI/UX improvements (floating windows, fuzzy finding)
- [ ] Code generation enhancements
- [ ] Navigation and discovery features

### Future Features
- [ ] Performance optimizations
- [ ] Advanced SystemVerilog support
- [ ] LSP integration
- [ ] Advanced code analysis tools

## Related Projects

- [verilog-autoinst.nvim](https://github.com/mingo99/verilog-autoinst.nvim) - Similar plugin for auto-instantiation
- [Digital-IDE](https://github.com/Digital-EDA/Digital-IDE) - Comprehensive Verilog IDE

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on top of the excellent [Verible](https://github.com/chipsalliance/verible) tool suite
- Inspired by various Verilog development tools and IDEs
- Thanks to the Neovim community for the amazing plugin ecosystem
