---日志工具模块
local M = {}

local config = nil

---延迟加载配置
local function get_config()
  if not config then
    config = require('nvim-python-venv.config')
  end
  return config
end

---日志级别映射
local levels = {
  debug = vim.log.levels.DEBUG,
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

---通用日志函数
---@param level string
---@param msg string
---@param opts table|nil
local function log(level, msg, opts)
  opts = opts or {}
  local cfg = get_config().get()

  if not cfg.ui.notify then
    return
  end

  local log_level = levels[level] or vim.log.levels.INFO
  local notify_level = levels[cfg.ui.notify_level] or vim.log.levels.INFO

  -- 只显示等于或高于配置级别的日志
  if log_level >= notify_level then
    vim.notify(msg, log_level, vim.tbl_extend('force', { title = 'Python Venv' }, opts))
  end
end

---调试日志
---@param msg string
---@param opts table|nil
function M.debug(msg, opts)
  log('debug', msg, opts)
end

---信息日志
---@param msg string
---@param opts table|nil
function M.info(msg, opts)
  log('info', msg, opts)
end

---警告日志
---@param msg string
---@param opts table|nil
function M.warn(msg, opts)
  log('warn', msg, opts)
end

---错误日志
---@param msg string
---@param opts table|nil
function M.error(msg, opts)
  log('error', msg, opts)
end

---格式化虚拟环境激活消息
---@param venv_path string
---@param venv_type string
function M.venv_activated(venv_path, venv_type)
  local short_path = vim.fn.fnamemodify(venv_path, ':~')
  M.info(string.format('Activated %s venv: %s', venv_type, short_path))
end

---格式化虚拟环境停用消息
function M.venv_deactivated()
  M.info('Deactivated virtual environment')
end

return M
