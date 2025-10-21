---Conda 虚拟环境管理器
local base = require('nvim-python-venv.managers.base')
local path = require('nvim-python-venv.common.path')
local shell = require('nvim-python-venv.common.shell')
local os_utils = require('nvim-python-venv.common.os')

local M = base.create_base('conda', 4)

function M.is_available()
  return shell.has_command('conda')
end

function M.is_project_venv(root_dir)
  local env_yml = path.join(root_dir, 'environment.yml')
  local env_yaml = path.join(root_dir, 'environment.yaml')
  return path.exists(env_yml) or path.exists(env_yaml)
end

function M.get_project_venv(root_dir)
  if not M.is_project_venv(root_dir) then
    return nil
  end

  -- 尝试从 environment.yml 读取环境名称
  local env_file = path.join(root_dir, 'environment.yml')
  if not path.exists(env_file) then
    env_file = path.join(root_dir, 'environment.yaml')
  end

  if path.exists(env_file) then
    local uv = vim.uv or vim.loop
    local fd = uv.fs_open(env_file, 'r', 438)
    if fd then
      local stat = uv.fs_fstat(fd)
      if stat then
        local content = uv.fs_read(fd, stat.size, 0)
        uv.fs_close(fd)

        if content then
          -- 简单解析 name: xxx
          local env_name = content:match('name:%s*([%w_-]+)')
          if env_name then
            -- 获取 conda 环境路径
            local success, output = shell.execute('conda env list')
            if success and output then
              for line in output:gmatch('[^\r\n]+') do
                if line:match('^' .. env_name .. '%s') then
                  local env_path = line:match('%s+(/[^%s]+)$')
                  if env_path and path.is_dir(env_path) then
                    return env_path
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  return nil
end

function M.get_global_venvs()
  local venvs = {}
  local success, output = shell.execute('conda env list')

  if success and output then
    for line in output:gmatch('[^\r\n]+') do
      -- 跳过注释和空行
      if not line:match('^#') and line:match('%S') then
        local env_path = line:match('%s+(/[^%s]+)$')
        if env_path and path.is_dir(env_path) then
          table.insert(venvs, env_path)
        end
      end
    end
  end

  return venvs
end

return M
