---本地 Venv 管理器（.venv, venv 等标准虚拟环境）
local base = require('nvim-python-venv.managers.base')
local path = require('nvim-python-venv.common.path')
local os_utils = require('nvim-python-venv.common.os')

local M = base.create_base('local_venv', 6)

-- 常见的本地虚拟环境目录名
local VENV_DIR_NAMES = { '.venv', 'venv', '.env', 'env' }

---检查本地虚拟环境总是可用的（不需要外部命令）
---@return boolean
function M.is_available()
  return true
end

---检查项目是否有本地虚拟环境
---@param root_dir string
---@return boolean
function M.is_project_venv(root_dir)
  for _, venv_name in ipairs(VENV_DIR_NAMES) do
    local venv_path = path.join(root_dir, venv_name)
    if path.is_dir(venv_path) then
      local python_path = os_utils.get_python_executable(venv_path)
      if path.exists(python_path) then
        return true
      end
    end
  end
  return false
end

---获取项目的本地虚拟环境路径
---@param root_dir string
---@return string|nil
function M.get_project_venv(root_dir)
  -- 按优先级查找
  for _, venv_name in ipairs(VENV_DIR_NAMES) do
    local venv_path = path.join(root_dir, venv_name)
    if path.is_dir(venv_path) then
      local python_path = os_utils.get_python_executable(venv_path)
      if path.exists(python_path) then
        return venv_path
      end
    end
  end
  return nil
end

---获取全局本地虚拟环境列表
---@return string[]
function M.get_global_venvs()
  -- 本地虚拟环境没有全局概念，返回空列表
  -- 可以考虑扫描常见项目目录，但这会很慢
  return {}
end

return M
