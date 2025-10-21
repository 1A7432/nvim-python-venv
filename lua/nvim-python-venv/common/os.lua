---操作系统相关工具模块
local M = {}

local uv = vim.uv or vim.loop

---检测操作系统类型
M.sysname = uv.os_uname().sysname
M.is_windows = M.sysname:find('Windows') ~= nil
M.is_mac = M.sysname == 'Darwin'
M.is_linux = M.sysname == 'Linux'

---获取环境变量
---@param name string
---@return string|nil
function M.getenv(name)
  return vim.env[name]
end

---设置环境变量
---@param name string
---@param value string|nil
function M.setenv(name, value)
  vim.env[name] = value
end

---获取 PATH 环境变量列表
---@return string[]
function M.get_path_list()
  local path_env = M.getenv('PATH') or ''
  local separator = M.is_windows and ';' or ':'
  return vim.split(path_env, separator, { plain = true })
end

---设置 PATH 环境变量
---@param paths string[]
function M.set_path_list(paths)
  local separator = M.is_windows and ';' or ':'
  M.setenv('PATH', table.concat(paths, separator))
end

---添加路径到 PATH 环境变量开头
---@param path_str string
function M.prepend_path(path_str)
  local paths = M.get_path_list()
  -- 移除已存在的相同路径
  paths = vim.tbl_filter(function(p)
    return p ~= path_str
  end, paths)
  -- 添加到开头
  table.insert(paths, 1, path_str)
  M.set_path_list(paths)
end

---从 PATH 环境变量中移除路径
---@param path_str string
function M.remove_path(path_str)
  local paths = M.get_path_list()
  paths = vim.tbl_filter(function(p)
    return p ~= path_str
  end, paths)
  M.set_path_list(paths)
end

---检查可执行文件是否存在
---@param name string
---@return boolean
function M.executable(name)
  return vim.fn.executable(name) == 1
end

---查找可执行文件的完整路径
---@param name string
---@return string|nil
function M.which(name)
  if M.executable(name) then
    return vim.fn.exepath(name)
  end
  return nil
end

---获取 Python 可执行文件路径（根据平台）
---@param venv_path string
---@return string
function M.get_python_executable(venv_path)
  if M.is_windows then
    return venv_path .. '/Scripts/python.exe'
  else
    return venv_path .. '/bin/python'
  end
end

---获取激活脚本路径（根据平台）
---@param venv_path string
---@return string
function M.get_activate_script(venv_path)
  if M.is_windows then
    return venv_path .. '/Scripts/activate.bat'
  else
    return venv_path .. '/bin/activate'
  end
end

return M
