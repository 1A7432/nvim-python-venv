---@class CacheConfig
---@field enabled boolean 启用缓存
---@field file_path string 缓存文件路径
---@field expire_time number 缓存过期时间（秒），0表示永不过期
---@field auto_clean boolean 自动清理无效缓存

---@class ManagersConfig
---@field priority string[] 虚拟环境管理器优先级列表
---@field enabled table<string, boolean> 各管理器启用状态

---@class LspConfig
---@field servers string[] 支持的 LSP 服务器列表
---@field restart_on_venv_change boolean 虚拟环境变更时自动重启 LSP
---@field timeout number LSP 操作超时时间（毫秒）

---@class UIConfig
---@field selector string UI 选择器类型 ('telescope'|'fzf-lua'|'fzf-vim'|'nui'|'vim-ui')
---@field notify boolean 显示通知
---@field notify_level string 通知级别 ('info'|'warn'|'error')
---@field statusline boolean 启用状态栏集成

---@class HooksConfig
---@field on_venv_activate fun(venv_path: string): nil 虚拟环境激活时的钩子
---@field on_venv_deactivate fun(): nil 虚拟环境停用时的钩子
---@field on_lsp_attach fun(client: vim.lsp.Client, bufnr: integer): nil LSP 附加时的钩子

---@class Config
---@field auto_detect boolean 自动检测虚拟环境
---@field auto_activate boolean 自动激活虚拟环境
---@field auto_restart_lsp boolean 自动重启 LSP
---@field cache CacheConfig 缓存配置
---@field managers ManagersConfig 管理器配置
---@field lsp LspConfig LSP 配置
---@field ui UIConfig UI 配置
---@field hooks HooksConfig 钩子配置

local M = {}

---@type Config
M.default = {
  -- 零配置优先：默认全部自动化
  auto_detect = true,
  auto_activate = true,
  auto_restart_lsp = true,

  cache = {
    enabled = true,
    file_path = vim.fn.stdpath('cache') .. '/nvim-python-venv/cache.json',
    expire_time = 0, -- 永不过期，通过文件监视失效
    auto_clean = true,
  },

  managers = {
    -- 按照设计文档的优先级排序
    priority = {
      'uv',
      'poetry',
      'pipenv',
      'conda',
      'pyenv',
      'local_venv',
      'virtualenvwrapper',
    },
    enabled = {
      uv = true,
      poetry = true,
      pipenv = true,
      conda = true,
      pyenv = true,
      local_venv = true,
      virtualenvwrapper = true,
    },
  },

  lsp = {
    servers = { 'basedpyright', 'pyright', 'pylsp', 'jedi_language_server' },
    restart_on_venv_change = true,
    timeout = 5000,
  },

  ui = {
    selector = 'auto', -- 自动检测可用的选择器
    notify = true,
    notify_level = 'info',
    statusline = true,
  },

  hooks = {
    on_venv_activate = function(venv_path) end,
    on_venv_deactivate = function() end,
    on_lsp_attach = function(client, bufnr) end,
  },
}

---@type Config
M._config = vim.deepcopy(M.default)

---验证并规范化配置
---@param user_config Config|nil
---@return Config
local function validate_config(user_config)
  if not user_config or type(user_config) ~= 'table' then
    return M._config
  end

  -- 深度合并用户配置
  local config = vim.tbl_deep_extend('force', M._config, user_config)

  -- 验证缓存路径
  if config.cache.file_path then
    local path = config.cache.file_path
    if not path:match('%.json$') then
      vim.notify(
        '[nvim-python-venv] Invalid cache path, must end with .json: ' .. path,
        vim.log.levels.WARN
      )
      config.cache.file_path = M.default.cache.file_path
    end
  end

  -- 验证 UI 选择器
  local valid_selectors = { 'auto', 'telescope', 'fzf-lua', 'fzf-vim', 'nui', 'vim-ui' }
  if not vim.tbl_contains(valid_selectors, config.ui.selector) then
    vim.notify(
      '[nvim-python-venv] Invalid UI selector: ' .. config.ui.selector .. ', using auto',
      vim.log.levels.WARN
    )
    config.ui.selector = 'auto'
  end

  return config
end

---更新配置
---@param user_config Config|nil
function M.update(user_config)
  M._config = validate_config(user_config)
end

---获取当前配置
---@return Config
function M.get()
  return M._config
end

---重置为默认配置
function M.reset()
  M._config = vim.deepcopy(M.default)
end

return M
