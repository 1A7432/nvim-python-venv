---Pipenv 虚拟环境管理器
local base = require('nvim-python-venv.managers.base')
local path = require('nvim-python-venv.common.path')
local shell = require('nvim-python-venv.common.shell')
local os_utils = require('nvim-python-venv.common.os')

local M = base.create_base('pipenv', 3)

function M.is_available()
  return shell.has_command('pipenv')
end

function M.is_project_venv(root_dir)
  local pipfile = path.join(root_dir, 'Pipfile')
  local pipfile_lock = path.join(root_dir, 'Pipfile.lock')
  return path.exists(pipfile) or path.exists(pipfile_lock)
end

function M.get_project_venv(root_dir)
  if not M.is_project_venv(root_dir) then
    return nil
  end

  local success, output = shell.execute('pipenv --venv', { cwd = root_dir })
  if success and output and output ~= '' then
    local venv_path = output:gsub('%s+$', '')
    if path.is_dir(venv_path) then
      local python_path = os_utils.get_python_executable(venv_path)
      if path.exists(python_path) then
        return venv_path
      end
    end
  end

  return nil
end

function M.get_global_venvs()
  return {}
end

return M
