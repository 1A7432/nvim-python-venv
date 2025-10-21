---Poetry 虚拟环境管理器
local base = require('nvim-python-venv.managers.base')
local path = require('nvim-python-venv.common.path')
local shell = require('nvim-python-venv.common.shell')
local os_utils = require('nvim-python-venv.common.os')

local M = base.create_base('poetry', 2)

---检查 poetry 命令是否可用
---@return boolean
function M.is_available()
  return shell.has_command('poetry')
end

---检查项目是否使用 Poetry
---@param root_dir string
---@return boolean
function M.is_project_venv(root_dir)
  -- 检查 poetry.lock 或 pyproject.toml with poetry section
  local lock_file = path.join(root_dir, 'poetry.lock')
  if path.exists(lock_file) then
    return true
  end

  local pyproject = path.join(root_dir, 'pyproject.toml')
  if path.exists(pyproject) then
    -- 简单检查：读取文件查找 [tool.poetry]
    local uv = vim.uv or vim.loop
    local fd = uv.fs_open(pyproject, 'r', 438)
    if fd then
      local stat = uv.fs_fstat(fd)
      if stat then
        local content = uv.fs_read(fd, stat.size, 0)
        uv.fs_close(fd)
        if content and content:match('%[tool%.poetry%]') then
          return true
        end
      end
    end
  end

  return false
end

---获取项目的 Poetry 虚拟环境路径
---@param root_dir string
---@return string|nil
function M.get_project_venv(root_dir)
  if not M.is_project_venv(root_dir) then
    return nil
  end

  -- 执行 poetry env info -p 获取虚拟环境路径
  local success, output = shell.execute('poetry env info -p', { cwd = root_dir })

  if success and output and output ~= '' then
    local venv_path = output:gsub('%s+$', '')

    -- 验证路径存在
    if path.is_dir(venv_path) then
      local python_path = os_utils.get_python_executable(venv_path)
      if path.exists(python_path) then
        return venv_path
      end
    end
  end

  return nil
end

---获取所有 Poetry 虚拟环境
---@return string[]
function M.get_global_venvs()
  local venvs = {}

  -- 尝试从 poetry config virtualenvs.path 获取虚拟环境目录
  local success, config_path = shell.execute('poetry config virtualenvs.path')

  if success and config_path and config_path ~= '' then
    local venvs_dir = config_path:gsub('%s+$', '')

    if path.is_dir(venvs_dir) then
      local entries = path.list_dir(venvs_dir)
      if entries then
        for _, entry in ipairs(entries) do
          if entry.type == 'directory' then
            local venv_path = path.join(venvs_dir, entry.name)
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
