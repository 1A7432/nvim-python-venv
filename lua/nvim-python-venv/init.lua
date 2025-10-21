---nvim-python-venv 主入口
---增强版 Neovim Python 虚拟环境管理插件
local M = {}

M._initialized = false

---Setup 插件
---@param user_config Config|nil 用户配置
function M.setup(user_config)
  if M._initialized then
    return
  end

  -- 加载配置
  local config = require('nvim-python-venv.config')
  config.update(user_config)
  local cfg = config.get()

  -- 初始化缓存系统
  local cache = require('nvim-python-venv.cache')
  cache.init(cfg)

  -- 注册用户命令
  local commands = require('nvim-python-venv.commands')
  commands.setup_commands(cfg)

  -- 设置自动命令
  M.setup_autocmds(cfg)

  -- 集成 LSP（如果支持）
  M.setup_lsp_integration(cfg)

  M._initialized = true

  local logger = require('nvim-python-venv.common.logger')
  logger.debug('nvim-python-venv initialized')
end

---设置自动命令
---@param config Config
function M.setup_autocmds(config)
  local venv_core = require('nvim-python-venv.venv')

  -- 创建 autocmd 组
  local augroup = vim.api.nvim_create_augroup('NvimPythonVenv', { clear = true })

  if config.auto_activate then
    -- 进入 Python buffer 时自动激活虚拟环境
    vim.api.nvim_create_autocmd('BufEnter', {
      group = augroup,
      pattern = '*.py',
      callback = function()
        venv_core.activate_for_buffer(nil, config)
      end,
    })

    -- VimEnter 时对当前 buffer 激活
    vim.api.nvim_create_autocmd('VimEnter', {
      group = augroup,
      pattern = '*.py',
      callback = function()
        -- 延迟执行，确保 LSP 已加载
        vim.defer_fn(function()
          venv_core.activate_for_buffer(nil, config)
        end, 100)
      end,
    })
  end
end

---设置 LSP 集成
---@param config Config
function M.setup_lsp_integration(config)
  local lsp_core = require('nvim-python-venv.lsp')

  -- 检查 Neovim 版本
  local nvim_0_11 = vim.fn.has('nvim-0.11') == 1

  if nvim_0_11 then
    -- Neovim 0.11+ 使用原生 LSP API
    M.setup_native_lsp(config, lsp_core)
  end

  -- 检查是否安装了 lspconfig
  local has_lspconfig, lspconfig = pcall(require, 'lspconfig')
  if has_lspconfig then
    M.setup_lspconfig(config, lsp_core, lspconfig)
  end
end

---设置原生 LSP 集成（Neovim 0.11+）
---@param config Config
---@param lsp_core table
function M.setup_native_lsp(config, lsp_core)
  -- Hook into native LSP
  local original_start_client = vim.lsp.start_client or vim.lsp.start

  if not original_start_client then
    return
  end

  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.start_client = function(lsp_config)
    -- 只处理 Python LSP
    if not lsp_config.name or not vim.tbl_contains(config.lsp.servers, lsp_config.name) then
      return original_start_client(lsp_config)
    end

    -- 注入钩子
    local original_on_new_config = lsp_config.on_new_config
    lsp_config.on_new_config = function(new_config, root_dir)
      -- 先调用我们的钩子
      lsp_core.make_on_new_config_hook(config)(new_config, root_dir)

      -- 再调用原始钩子
      if original_on_new_config then
        original_on_new_config(new_config, root_dir)
      end
    end

    local original_on_attach = lsp_config.on_attach
    lsp_config.on_attach = function(client, bufnr)
      -- 先调用我们的钩子
      lsp_core.make_on_attach_hook(config)(client, bufnr)

      -- 再调用原始钩子
      if original_on_attach then
        original_on_attach(client, bufnr)
      end
    end

    return original_start_client(lsp_config)
  end
end

---设置 lspconfig 集成
---@param config Config
---@param lsp_core table
---@param lspconfig table
function M.setup_lspconfig(config, lsp_core, lspconfig)
  -- Hook 所有支持的 Python LSP 服务器
  for _, server_name in ipairs(config.lsp.servers) do
    local server_config = lspconfig[server_name]

    if server_config then
      local original_setup = server_config.setup

      ---@diagnostic disable-next-line: duplicate-set-field
      server_config.setup = function(opts)
        opts = opts or {}

        -- 注入 on_new_config 钩子
        local original_on_new_config = opts.on_new_config
        opts.on_new_config = function(new_config, root_dir)
          lsp_core.make_on_new_config_hook(config)(new_config, root_dir)
          if original_on_new_config then
            original_on_new_config(new_config, root_dir)
          end
        end

        -- 注入 on_attach 钩子
        local original_on_attach = opts.on_attach
        opts.on_attach = function(client, bufnr)
          lsp_core.make_on_attach_hook(config)(client, bufnr)
          if original_on_attach then
            original_on_attach(client, bufnr)
          end
        end

        return original_setup(opts)
      end
    end
  end
end

---获取当前虚拟环境（用于状态栏集成）
---@return string|nil
function M.get_active_venv()
  local venv_core = require('nvim-python-venv.venv')
  local current = venv_core.get_current()

  if current then
    local path_utils = require('nvim-python-venv.common.path')
    return path_utils.basename(current)
  end

  return nil
end

---获取虚拟环境状态（用于状态栏集成）
---@return table|nil {name: string, path: string, python_version: string, manager: string}
function M.get_venv_status()
  local venv_core = require('nvim-python-venv.venv')
  local info = venv_core.get_info()

  if not info then
    return nil
  end

  local path_utils = require('nvim-python-venv.common.path')

  return {
    name = path_utils.basename(info.path),
    path = info.path,
    python_version = info.python_version,
    manager = info.manager_type,
  }
end

---获取虚拟环境图标（用于状态栏集成）
---@return string
function M.get_venv_icon()
  local venv_core = require('nvim-python-venv.venv')
  local info = venv_core.get_info()

  if not info then
    return ''
  end

  -- 根据管理器类型返回不同图标
  local icons = {
    conda = '🅒',
    poetry = '📜',
    pipenv = '📦',
    pyenv = '🐍',
    uv = '⚡',
    local_venv = '🔧',
    virtualenvwrapper = '🔄',
  }

  return icons[info.manager_type] or '🐍'
end

return M
