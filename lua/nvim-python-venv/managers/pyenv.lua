---Pyenv 虚拟环境管理器
local base = require('nvim-python-venv.managers.base')
local path = require('nvim-python-venv.common.path')
local shell = require('nvim-python-venv.common.shell')
local os_utils = require('nvim-python-venv.common.os')

local M = base.create_base('pyenv', 5)

function M.is_available()
  return shell.has_command('pyenv')
end

function M.is_project_venv(root_dir)
  local python_version_file = path.join(root_dir, '.python-version')
  return path.exists(python_version_file)
end

function M.get_project_venv(root_dir)
  if not M.is_project_venv(root_dir) then
    return nil
  end

  -- pyenv 本身不直接管理虚拟环境，但可以通过 pyenv which python 获取
  local success, output = shell.execute('pyenv which python', { cwd = root_dir })
  if success and output and output ~= '' then
    local python_path = output:gsub('%s+$', '')
    if path.exists(python_path) then
      -- 提取虚拟环境路径（去掉 /bin/python 部分）
      local venv_path = path.dirname(path.dirname(python_path))
      return venv_path
    end
  end

  return nil
end

function M.get_global_venvs()
  local venvs = {}
  local pyenv_root = os_utils.getenv('PYENV_ROOT')

  if not pyenv_root then
    local success, output = shell.execute('pyenv root')
    if success and output then
      pyenv_root = output:gsub('%s+$', '')
    end
  end

  if pyenv_root then
    local versions_dir = path.join(pyenv_root, 'versions')
    if path.is_dir(versions_dir) then
      local entries = path.list_dir(versions_dir)
      if entries then
        for _, entry in ipairs(entries) do
          if entry.type == 'directory' then
            local venv_path = path.join(versions_dir, entry.name)
            local python_path = os_utils.get_python_executable(venv_path)
            if path.exists(python_path) then
              table.insert(venvs, venv_path)
            end
          end
        end
      end
    end
  end

  return venvs
end

return M
