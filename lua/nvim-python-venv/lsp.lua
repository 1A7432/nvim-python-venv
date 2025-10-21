---LSP 集成核心模块
---负责与 Neovim LSP 深度集成，处理虚拟环境切换时的 LSP 配置更新
local venv = require('nvim-python-venv.venv')
local cache = require('nvim-python-venv.cache')
local logger = require('nvim-python-venv.common.logger')
local os_utils = require('nvim-python-venv.common.os')

local M = {}

-- 支持的 LSP 服务器配置
local LSP_CONFIGS = {
  pyright = {
    settings_key = 'python.pythonPath',
    update_fn = function(settings, python_path)
      settings.python = settings.python or {}
      settings.python.pythonPath = python_path
    end,
  },
  basedpyright = {
    settings_key = 'python.pythonPath',
    update_fn = function(settings, python_path)
      settings.python = settings.python or {}
      settings.python.pythonPath = python_path
    end,
  },
  pylsp = {
    settings_key = 'pylsp.plugins.jedi.environment',
    update_fn = function(settings, python_path)
      settings.pylsp = settings.pylsp or {}
      settings.pylsp.plugins = settings.pylsp.plugins or {}
      settings.pylsp.plugins.jedi = settings.pylsp.plugins.jedi or {}
      settings.pylsp.plugins.jedi.environment = python_path
    end,
  },
  jedi_language_server = {
    init_options_key = 'workspace.environmentPath',
    update_fn = function(init_options, python_path)
      init_options.workspace = init_options.workspace or {}
      init_options.workspace.environmentPath = python_path
    end,
  },
}

---检查客户端是否为 Python LSP
---@param client vim.lsp.Client
---@return boolean
local function is_python_lsp(client)
  return LSP_CONFIGS[client.name] ~= nil
end

---更新 LSP 配置中的 Python 路径
---@param config table LSP 配置
---@param python_path string Python 解释器路径
---@param server_name string LSP 服务器名称
local function update_lsp_config(config, python_path, server_name)
  local lsp_config = LSP_CONFIGS[server_name]
  if not lsp_config then
    return
  end

  -- 更新 settings
  if lsp_config.settings_key then
    config.settings = config.settings or {}
    lsp_config.update_fn(config.settings, python_path)
  end

  -- 更新 init_options
  if lsp_config.init_options_key then
    config.init_options = config.init_options or {}
    lsp_config.update_fn(config.init_options, python_path)
  end

  -- 保存虚拟环境路径到配置（用于后续恢复）
  config._venv_python_path = python_path
end

---root_dir 钩子：从缓存中优先查找已知的 root_dir
---@param config Config
---@return fun(pattern: string): string|nil
function M.make_root_dir_hook(config)
  return function(pattern)
    local bufnr = vim.api.nvim_get_current_buf()
    local buf_name = vim.api.nvim_buf_get_name(bufnr)

    if buf_name == '' then
      return nil
    end

    -- 优先从缓存中查找
    local root_dir = cache.find_root_by_file(buf_name)
    if root_dir then
      return root_dir
    end

    -- 使用默认的 root_dir 查找逻辑
    local found_root = venv.find_root_dir(buf_name)
    return found_root
  end
end

---before_init / on_new_config 钩子：在 LSP 初始化前激活虚拟环境
---@param config Config
---@return fun(new_config: table, root_dir: string): nil
function M.make_on_new_config_hook(config)
  return function(new_config, root_dir)
    if not config.auto_activate then
      return
    end

    -- 检测虚拟环境
    local venv_path, manager_type = venv.detect(root_dir, config)

    if venv_path then
      local python_path = os_utils.get_python_executable(venv_path)

      -- 更新 LSP 配置
      update_lsp_config(new_config, python_path, new_config.name)

      -- 保存虚拟环境路径到配置（供 on_attach 使用）
      new_config._venv_path = venv_path
      new_config._venv_root = root_dir
    end
  end
end

---on_attach 钩子：将虚拟环境保存到 buffer 变量
---@param config Config
---@return fun(client: vim.lsp.Client, bufnr: integer): nil
function M.make_on_attach_hook(config)
  return function(client, bufnr)
    if not is_python_lsp(client) then
      return
    end

    local venv_path = client.config._venv_path
    local root_dir = client.config._venv_root

    if venv_path then
      -- 保存到 buffer 变量
      vim.api.nvim_buf_set_var(bufnr, 'VIRTUAL_ENV', venv_path)
      if root_dir then
        vim.api.nvim_buf_set_var(bufnr, 'VIRTUAL_ENV_ROOT', root_dir)
      end

      -- 激活虚拟环境
      venv.activate(venv_path, config)
    end

    -- 调用用户自定义钩子
    if config.hooks.on_lsp_attach then
      config.hooks.on_lsp_attach(client, bufnr)
    end
  end
end

---重启指定 buffer 的 Python LSP
---@param bufnr integer|nil
function M.restart_buffer_lsp(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  for _, client in ipairs(clients) do
    if is_python_lsp(client) then
      vim.lsp.stop_client(client.id)

      -- 延迟重启（等待客户端完全停止）
      vim.defer_fn(function()
        vim.api.nvim_exec_autocmds('FileType', {
          pattern = 'python',
          buffer = bufnr,
        })
      end, 100)
    end
  end
end

---重启指定 root_dir 下所有 buffer 的 Python LSP
---@param root_dir string
function M.restart_root_lsp(root_dir)
  local buffers = vim.api.nvim_list_bufs()

  for _, bufnr in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local ok, buf_root = pcall(vim.api.nvim_buf_get_var, bufnr, 'VIRTUAL_ENV_ROOT')
      if ok and buf_root == root_dir then
        M.restart_buffer_lsp(bufnr)
      end
    end
  end
end

---获取 Python LSP 客户端列表
---@param bufnr integer|nil
---@return vim.lsp.Client[]
function M.get_python_clients(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  return vim.tbl_filter(is_python_lsp, clients)
end

return M
