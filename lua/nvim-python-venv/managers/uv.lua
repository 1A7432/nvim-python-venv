---UV 虚拟环境管理器
local base = require('nvim-python-venv.managers.base')
local path = require('nvim-python-venv.common.path')
local shell = require('nvim-python-venv.common.shell')
local os_utils = require('nvim-python-venv.common.os')

local M = base.create_base('uv', 1) -- 最高优先级

---检查 uv 命令是否可用
---@return boolean
function M.is_available()
  return shell.has_command('uv')
end

---检查项目是否使用 UV
---@param root_dir string
---@return boolean
function M.is_project_venv(root_dir)
  -- 检查 uv.lock 文件
  local lock_file = path.join(root_dir, 'uv.lock')
  return path.exists(lock_file)
end

---获取项目的 UV 虚拟环境路径
---@param root_dir string
---@return string|nil
function M.get_project_venv(root_dir)
  if not M.is_project_venv(root_dir) then
    return nil
  end

  -- UV 默认使用项目根目录下的 .venv
  local venv_path = path.join(root_dir, '.venv')

  -- 验证虚拟环境是否存在
  if not path.is_dir(venv_path) then
    return nil
  end

  -- 验证 Python 可执行文件是否存在
  local python_path = os_utils.get_python_executable(venv_path)
  if not path.exists(python_path) then
    return nil
  end

  return venv_path
end

---获取所有 UV 管理的虚拟环境
---@return string[]
function M.get_global_venvs()
  -- UV 没有全局虚拟环境的概念，只有项目级别的虚拟环境
  -- 可以尝试列出常见位置的 UV 项目
  return {}
end

return M
