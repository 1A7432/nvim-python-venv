# 快速入门指南

## 5 分钟上手 nvim-python-venv

### 📦 第一步：安装

在你的 Neovim 配置中添加（使用 lazy.nvim）：

```lua
{
  dir = '/Users/darthvader/ClaudeCode/my_nvim/MyNVim/nvim-python-venv',
  name = 'nvim-python-venv',
  ft = 'python',
  config = function()
    require('nvim-python-venv').setup()
  end,
}
```

### 🚀 第二步：重启 Neovim

重启 Neovim 或执行 `:Lazy sync`

### 🐍 第三步：打开 Python 文件

打开任何 Python 文件，插件会自动：

1. 检测项目的虚拟环境管理器（UV、Poetry、Pipenv 等）
2. 激活对应的虚拟环境
3. 配置 LSP 使用正确的 Python 解释器
4. 显示通知告诉你激活了哪个虚拟环境

### ✨ 第四步：验证

运行 `:VenvInfo` 查看当前虚拟环境信息：

```
Virtual Environment Information:
  Path: /path/to/your/project/.venv
  Python: /path/to/your/project/.venv/bin/python
  Version: 3.11.5
  Manager: poetry
  Active: Yes
```

## 常见场景

### 场景 1：项目有 Poetry 配置

```bash
# 你的项目结构
my-project/
├── pyproject.toml
├── poetry.lock
├── .venv/
└── src/
    └── main.py
```

**操作：** 打开 `src/main.py`

**结果：** ✅ 自动激活 `.venv` 虚拟环境

### 场景 2：手动选择虚拟环境

如果自动检测失败或想使用其他虚拟环境：

```vim
:VenvSelect
```

然后从列表中选择你想要的虚拟环境。

### 场景 3：Monorepo 多项目

```bash
monorepo/
├── project-a/
│   ├── pyproject.toml
│   └── .venv/
├── project-b/
│   ├── pyproject.toml
│   └── .venv/
└── project-c/
    ├── pyproject.toml
    └── .venv/
```

**操作：** 
1. 打开 `project-a/main.py`
2. 运行 `:VenvAdd` 手动添加映射
3. 选择 `project-a/` 作为 root
4. 选择 `project-a/.venv` 作为虚拟环境

**结果：** ✅ 以后打开 project-a 下的任何文件都会自动使用正确的虚拟环境

### 场景 4：状态栏显示

在 lualine 配置中添加：

```lua
{
  function()
    local venv = require('nvim-python-venv')
    local status = venv.get_venv_status()
    if status then
      return '🐍 ' .. status.name
    end
    return ''
  end,
  color = { fg = '#98c379' },
}
```

**结果：** ✅ 状态栏显示 `🐍 my-project`

## 常用命令速查

| 命令 | 用途 | 快捷键建议 |
|-----|------|----------|
| `:VenvSelect` | 选择虚拟环境 | `<leader>vs` |
| `:VenvInfo` | 查看当前环境信息 | `<leader>vi` |
| `:VenvAdd` | 添加虚拟环境映射 | `<leader>va` |
| `:VenvLspRestart` | 重启 Python LSP | `<leader>vr` |
| `:VenvRefresh` | 刷新虚拟环境列表 | - |

### 推荐快捷键配置

```lua
vim.keymap.set('n', '<leader>vs', ':VenvSelect<CR>', { desc = 'Select Venv' })
vim.keymap.set('n', '<leader>vi', ':VenvInfo<CR>', { desc = 'Venv Info' })
vim.keymap.set('n', '<leader>va', ':VenvAdd<CR>', { desc = 'Add Venv' })
vim.keymap.set('n', '<leader>vr', ':VenvLspRestart<CR>', { desc = 'Restart LSP' })
```

## 故障排查

### 问题：虚拟环境未自动检测

**检查：**
1. 确认项目有虚拟环境管理器的标志文件（如 `poetry.lock`）
2. 确认虚拟环境目录存在且有 Python 可执行文件
3. 运行 `:VenvInfo` 查看状态

**解决：**
- 手动运行 `:VenvAdd` 添加映射
- 或运行 `:VenvSelect` 选择虚拟环境

### 问题：LSP 没有使用正确的 Python

**检查：**
1. 运行 `:VenvInfo` 确认虚拟环境已激活
2. 检查 LSP 状态 `:LspInfo`

**解决：**
- 运行 `:VenvLspRestart` 重启 LSP

### 问题：不同 buffer 使用了错误的虚拟环境

**检查：**
- 这通常发生在 monorepo 场景

**解决：**
- 为每个子项目运行 `:VenvAdd` 手动添加映射
- 插件会自动为不同 buffer 使用正确的虚拟环境

## 性能优化建议

### 大型项目

如果你的项目非常大，可以禁用某些不需要的管理器：

```lua
require('nvim-python-venv').setup({
  managers = {
    enabled = {
      conda = false,  -- 不使用 Conda
      pipenv = false, -- 不使用 Pipenv
    },
  },
})
```

### 减少通知

如果觉得通知太多，可以调整通知级别：

```lua
require('nvim-python-venv').setup({
  ui = {
    notify_level = 'warn', -- 只显示警告和错误
  },
})
```

或完全禁用通知：

```lua
require('nvim-python-venv').setup({
  ui = {
    notify = false,
  },
})
```

## 下一步

- 查看 [README.md](./README.md) 了解完整功能
- 查看 [examples/config.lua](./examples/config.lua) 了解高级配置
- 查看 [ARCHITECTURE.md](./ARCHITECTURE.md) 了解内部架构

## 需要帮助？

如果遇到问题，请：
1. 检查 `:checkhealth` 输出
2. 查看 `:messages` 了解错误信息
3. 提交 Issue 到 GitHub

祝你使用愉快！🎉
