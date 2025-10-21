---Virtualenvwrapper 虚拟环境管理器
local base = require('nvim-python-venv.managers.base')
local path = require('nvim-python-venv.common.path')
local os_utils = require('nvim-python-venv.common.os')

local M = base.create_base('virtualenvwrapper', 7)

function M.is_available()
  local workon_home = os_utils.getenv('WORKON_HOME')
  return workon_home ~= nil and path.is_dir(workon_home)
end

function M.is_project_venv(root_dir)
  local workon_home = os_utils.getenv('WORKON_HOME')
  if not workon_home then
    return false
  end

  local project_name = path.basename(root_dir)
  local venv_path = path.join(workon_home, project_name)

  return path.is_dir(venv_path)
end

function M.get_project_venv(root_dir)
  if not M.is_project_venv(root_dir) then
    return nil
  end

  local workon_home = os_utils.getenv('WORKON_HOME')
  local project_name = path.basename(root_dir)
  local venv_path = path.join(workon_home, project_name)

  local python_path = os_utils.get_python_executable(venv_path)
  if path.exists(python_path) then
    return venv_path
  end

  return nil
end

function M.get_global_venvs()
  local venvs = {}
  local workon_home = os_utils.getenv('WORKON_HOME')

  if workon_home and path.is_dir(workon_home) then
    local entries = path.list_dir(workon_home)
    if entries then
      for _, entry in ipairs(entries) do
        if entry.type == 'directory' then
          local venv_path = path.join(workon_home, entry.name)
          local python_path = os_utils.get_python_executable(venv_path)
          if path.exists(python_path) then
            table.insert(venvs, venv_path)
          end
        end
      end
    end
  end

  return venvs
end

return M
