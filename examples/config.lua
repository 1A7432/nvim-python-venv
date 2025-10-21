-- nvim-python-venv 使用示例配置
-- 将此文件内容复制到你的 Neovim 配置中

-- 示例 1: 零配置（推荐）
-- 最简单的用法，使用所有默认配置
return {
  {
    dir = '/Users/darthvader/ClaudeCode/my_nvim/MyNVim/nvim-python-venv',
    name = 'nvim-python-venv',
    ft = 'python',
    config = function()
      require('nvim-python-venv').setup()
    end,
  }
}

-- 示例 2: 基本自定义
-- 禁用某些管理器，自定义通知级别
--[[ 
return {
  {
    dir = '/Users/darthvader/ClaudeCode/my_nvim/MyNVim/nvim-python-venv',
    name = 'nvim-python-venv',
    ft = 'python',
    config = function()
      require('nvim-python-venv').setup({
        managers = {
          enabled = {
            conda = false,  -- 不使用 Conda
            pipenv = false, -- 不使用 Pipenv
          },
        },
        ui = {
          notify_level = 'warn', -- 只显示警告和错误
        },
      })
    end,
  }
}
]]

-- 示例 3: 高级配置
-- 自定义优先级、钩子函数、状态栏集成
--[[ 
return {
  {
    dir = '/Users/darthvader/ClaudeCode/my_nvim/MyNVim/nvim-python-venv',
    name = 'nvim-python-venv',
    ft = 'python',
    dependencies = {
      'nvim-lualine/lualine.nvim', -- 可选：状态栏集成
    },
    config = function()
      require('nvim-python-venv').setup({
        -- 自定义管理器优先级
        managers = {
          priority = {
            'poetry',  -- Poetry 优先
            'uv',
            'local_venv',
            'pyenv',
          },
        },

        -- 钩子函数
        hooks = {
          on_venv_activate = function(venv_path)
            -- 虚拟环境激活时执行
            print('Activated venv: ' .. venv_path)
            
            -- 例如：自动安装依赖检查
            vim.defer_fn(function()
              local requirements = venv_path:gsub('%.venv', '') .. '/requirements.txt'
              if vim.fn.filereadable(requirements) == 1 then
                vim.notify('Found requirements.txt', vim.log.levels.INFO)
              end
            end, 1000)
          end,

          on_lsp_attach = function(client, bufnr)
            -- LSP 附加时设置快捷键
            local opts = { buffer = bufnr, silent = true }
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
            vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
            vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
          end,
        },
      })

      -- 状态栏集成示例（lualine）
      require('lualine').setup({
        sections = {
          lualine_x = {
            {
              function()
                local venv = require('nvim-python-venv')
                local status = venv.get_venv_status()
                if status then
                  return string.format(
                    '%s %s (Python %s)',
                    venv.get_venv_icon(),
                    status.name,
                    status.python_version
                  )
                end
                return ''
              end,
              color = { fg = '#98c379', gui = 'bold' },
              cond = function()
                return vim.bo.filetype == 'python'
              end,
            },
          },
        },
      })

      -- 快捷键配置示例
      vim.keymap.set('n', '<leader>vs', ':VenvSelect<CR>', { desc = 'Select Venv' })
      vim.keymap.set('n', '<leader>va', ':VenvAdd<CR>', { desc = 'Add Venv' })
      vim.keymap.set('n', '<leader>vi', ':VenvInfo<CR>', { desc = 'Venv Info' })
      vim.keymap.set('n', '<leader>vr', ':VenvLspRestart<CR>', { desc = 'Restart LSP' })
    end,
  }
}
]]

-- 示例 4: Monorepo 项目配置
-- 处理包含多个 Python 子项目的 monorepo
--[[ 
return {
  {
    dir = '/Users/darthvader/ClaudeCode/my_nvim/MyNVim/nvim-python-venv',
    name = 'nvim-python-venv',
    ft = 'python',
    config = function()
      require('nvim-python-venv').setup({
        -- 启用持久化缓存，重要！
        cache = {
          enabled = true,
          auto_clean = false, -- 手动管理缓存
        },

        -- 手动为每个子项目配置虚拟环境
        -- 使用 :VenvAdd 命令手动添加映射
      })

      -- 为 monorepo 设置自动命令
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = '*/monorepo/project-a/*.py',
        callback = function()
          -- 确保使用正确的虚拟环境
          local cache = require('nvim-python-venv.cache')
          local venv_path = cache.get_venv('/path/to/monorepo/project-a')
          if not venv_path then
            vim.notify('Please run :VenvAdd to set up venv for project-a', vim.log.levels.WARN)
          end
        end,
      })
    end,
  }
}
]]

-- 示例 5: 禁用自动检测，手动管理
-- 适合需要完全手动控制的场景
--[[ 
return {
  {
    dir = '/Users/darthvader/ClaudeCode/my_nvim/MyNVim/nvim-python-venv',
    name = 'nvim-python-venv',
    ft = 'python',
    config = function()
      require('nvim-python-venv').setup({
        auto_detect = false,
        auto_activate = false,
        auto_restart_lsp = false,

        ui = {
          notify = false, -- 禁用通知
        },
      })

      -- 手动激活虚拟环境
      vim.keymap.set('n', '<leader>va', function()
        local venv_path = vim.fn.input('Venv path: ', '', 'dir')
        if venv_path ~= '' then
          vim.cmd('VenvActivate ' .. venv_path)
        end
      end, { desc = 'Manually activate venv' })
    end,
  }
}
]]
