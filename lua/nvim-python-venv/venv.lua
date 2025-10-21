---虚拟环境核心模块
---负责虚拟环境的检测、激活、停用等核心功能
local cache = require('nvim-python-venv.cache')
local managers = require('nvim-python-venv.managers')
local logger = require('nvim-python-venv.common.logger')
local os_utils = require('nvim-python-venv.common.os')
local path = require('nvim-python-venv.common.path')

local M = {}

-- 当前激活的虚拟环境
M._current_venv = nil
M._previous_venv = nil

---检测项目的虚拟环境
---@param root_dir string
---@param config Config
---@return string|nil venv_path
---@return string|nil manager_type
function M.detect(root_dir, config)
  if not config.auto_detect then
    return nil, nil
  end

  -- 1. 检查缓存
  local cached_venv = cache.get_venv(root_dir)
  if cached_venv and path.exists(cached_venv) then
    local metadata = cache.get_metadata(cached_venv)
    return cached_venv, metadata and metadata.manager_type or 'unknown'
  end

  -- 2. 自动检测
  local venv_path, manager_type = managers.auto_detect(root_dir, config)

  -- 3. 保存到缓存
  if venv_path then
    local metadata = managers.get_metadata(venv_path, manager_type, config)
    cache.set_venv(root_dir, venv_path, metadata)
  end

  return venv_path, manager_type
end

---激活虚拟环境
---@param venv_path string
---@param config Config
---@return boolean success
function M.activate(venv_path, config)
  if not path.exists(venv_path) then
    logger.error('Virtual environment does not exist: ' .. venv_path)
    return false
  end

  -- 验证 Python 可执行文件存在
  local python_path = os_utils.get_python_executable(venv_path)
  if not path.exists(python_path) then
    logger.error('Python executable not found in: ' .. venv_path)
    return false
  end

  -- 保存之前的虚拟环境
  M._previous_venv = M._current_venv

  -- 设置环境变量
  os_utils.setenv('VIRTUAL_ENV', venv_path)

  -- 更新 PATH（添加虚拟环境的 bin 目录到开头）
  local bin_dir = os_utils.is_windows and path.join(venv_path, 'Scripts')
    or path.join(venv_path, 'bin')
  os_utils.prepend_path(bin_dir)

  -- 设置 Neovim 的 Python 解释器
  vim.g.python3_host_prog = python_path

  M._current_venv = venv_path

  -- 触发钩子
  if config.hooks.on_venv_activate then
    config.hooks.on_venv_activate(venv_path)
  end

  -- 获取元数据用于日志
  local metadata = cache.get_metadata(venv_path)
  local manager_type = metadata and metadata.manager_type or 'unknown'

  logger.venv_activated(venv_path, manager_type)

  return true
end

---停用当前虚拟环境
---@param config Config
---@return boolean success
function M.deactivate(config)
  if not M._current_venv then
    logger.warn('No virtual environment is currently activated')
    return false
  end

  -- 从 PATH 中移除虚拟环境的 bin 目录
  local bin_dir = os_utils.is_windows and path.join(M._current_venv, 'Scripts')
    or path.join(M._current_venv, 'bin')
  os_utils.remove_path(bin_dir)

  -- 清除环境变量
  os_utils.setenv('VIRTUAL_ENV', nil)

  -- 重置 Python 解释器（如果有之前的，恢复之前的）
  if M._previous_venv then
    local python_path = os_utils.get_python_executable(M._previous_venv)
    vim.g.python3_host_prog = python_path
  else
    vim.g.python3_host_prog = nil
  end

  M._current_venv = nil

  -- 触发钩子
  if config.hooks.on_venv_deactivate then
    config.hooks.on_venv_deactivate()
  end

  logger.venv_deactivated()

  return true
end

---根据 buffer 激活虚拟环境
---@param bufnr number|nil
---@param config Config
---@return boolean success
function M.activate_for_buffer(bufnr, config)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- 检查 buffer 局部变量
  local ok, buf_venv = pcall(vim.api.nvim_buf_get_var, bufnr, 'VIRTUAL_ENV')
  if ok and buf_venv and path.exists(buf_venv) then
    -- buffer 已有虚拟环境，且与当前激活的不同
    if buf_venv ~= M._current_venv then
      return M.activate(buf_venv, config)
    end
    return true
  end

  -- 根据 buffer 文件查找 root_dir
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  if buf_name == '' then
    return false
  end

  local root_dir = cache.find_root_by_file(buf_name)
  if not root_dir then
    -- 尝试查找项目根目录
    root_dir = M.find_root_dir(buf_name)
  end

  if root_dir then
    local venv_path, manager_type = M.detect(root_dir, config)
    if venv_path then
      -- 保存到 buffer 变量
      vim.api.nvim_buf_set_var(bufnr, 'VIRTUAL_ENV', venv_path)
      vim.api.nvim_buf_set_var(bufnr, 'VIRTUAL_ENV_ROOT', root_dir)

      -- 激活虚拟环境
      return M.activate(venv_path, config)
    end
  end

  return false
end

---查找项目根目录
---@param file_path string
---@return string|nil
function M.find_root_dir(file_path)
  local root_markers = {
    'pyproject.toml',
    'setup.py',
    'setup.cfg',
    'requirements.txt',
    'Pipfile',
    '.git',
  }

  local current = path.dirname(file_path)
  local uv = vim.uv or vim.loop
  local home = uv.os_homedir()

  while current and current ~= '/' and current ~= home do
    for _, marker in ipairs(root_markers) do
      if path.exists(path.join(current, marker)) then
        return current
      end
    end

    local parent = path.dirname(current)
    if parent == current then
      break
    end
    current = parent
  end

  return nil
end

---获取当前激活的虚拟环境
---@return string|nil
function M.get_current()
  return M._current_venv
end

---获取虚拟环境信息
---@param venv_path string|nil
---@return table|nil
function M.get_info(venv_path)
  venv_path = venv_path or M._current_venv
  if not venv_path then
    return nil
  end

  local metadata = cache.get_metadata(venv_path)
  local python_path = os_utils.get_python_executable(venv_path)

  return {
    path = venv_path,
    python_path = python_path,
    python_version = metadata and metadata.python_version or 'unknown',
    manager_type = metadata and metadata.manager_type or 'unknown',
    is_active = venv_path == M._current_venv,
  }
end

return M
