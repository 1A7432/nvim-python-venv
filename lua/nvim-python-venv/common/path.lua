---路径处理工具模块
local M = {}

local uv = vim.uv or vim.loop
local is_windows = uv.os_uname().sysname:find('Windows') ~= nil

---规范化路径
---@param path_str string
---@return string
function M.normalize(path_str)
  if not path_str or path_str == '' then
    return ''
  end

  -- 替换反斜杠为正斜杠
  local normalized = path_str:gsub('\\', '/')

  -- 移除尾部斜杠
  normalized = normalized:gsub('/+$', '')

  -- 展开 ~ 为 home 目录
  if normalized:sub(1, 1) == '~' then
    local home = uv.os_homedir()
    normalized = home .. normalized:sub(2)
  end

  return normalized
end

---连接路径
---@param ... string
---@return string
function M.join(...)
  local parts = { ... }
  local result = table.concat(parts, '/')
  return M.normalize(result)
end

---检查路径是否存在
---@param path_str string
---@return boolean
function M.exists(path_str)
  local stat = uv.fs_stat(M.normalize(path_str))
  return stat ~= nil
end

---检查是否为目录
---@param path_str string
---@return boolean
function M.is_dir(path_str)
  local stat = uv.fs_stat(M.normalize(path_str))
  return stat ~= nil and stat.type == 'directory'
end

---检查是否为文件
---@param path_str string
---@return boolean
function M.is_file(path_str)
  local stat = uv.fs_stat(M.normalize(path_str))
  return stat ~= nil and stat.type == 'file'
end

---获取父目录
---@param path_str string
---@return string
function M.dirname(path_str)
  return vim.fn.fnamemodify(path_str, ':h')
end

---获取文件名
---@param path_str string
---@return string
function M.basename(path_str)
  return vim.fn.fnamemodify(path_str, ':t')
end

---检查文件扩展名
---@param path_str string
---@param ext string
---@return boolean
function M.has_ext(path_str, ext)
  if not ext:match('^%.') then
    ext = '.' .. ext
  end
  return vim.endswith(path_str, ext)
end

---确保目录存在
---@param dir_path string
---@return boolean success
---@return string? error
function M.ensure_dir(dir_path)
  local normalized = M.normalize(dir_path)
  if M.exists(normalized) then
    return true
  end

  -- 递归创建父目录
  local parent = M.dirname(normalized)
  if parent ~= normalized and parent ~= '' then
    local success, err = M.ensure_dir(parent)
    if not success then
      return false, err
    end
  end

  -- 创建目录
  local ok, err = uv.fs_mkdir(normalized, 493) -- 0755
  if not ok then
    return false, 'Failed to create directory: ' .. (err or 'unknown error')
  end

  return true
end

---确保文件存在（创建空文件）
---@param file_path string
---@return boolean success
---@return string? error
function M.ensure_file(file_path)
  local normalized = M.normalize(file_path)
  if M.exists(normalized) then
    return true
  end

  -- 确保父目录存在
  local parent = M.dirname(normalized)
  local success, err = M.ensure_dir(parent)
  if not success then
    return false, err
  end

  -- 创建空文件
  local fd = uv.fs_open(normalized, 'w', 420) -- 0644
  if not fd then
    return false, 'Failed to create file: ' .. normalized
  end
  uv.fs_close(fd)

  return true
end

---列出目录下的所有文件和目录
---@param dir_path string
---@return string[]|nil
function M.list_dir(dir_path)
  local normalized = M.normalize(dir_path)
  if not M.is_dir(normalized) then
    return nil
  end

  local handle = uv.fs_scandir(normalized)
  if not handle then
    return nil
  end

  local entries = {}
  while true do
    local name, type = uv.fs_scandir_next(handle)
    if not name then
      break
    end
    table.insert(entries, { name = name, type = type })
  end

  return entries
end

---检查路径是否在另一个路径的子路径中
---@param child_path string
---@param parent_path string
---@return boolean
function M.is_subpath(child_path, parent_path)
  local child = M.normalize(child_path)
  local parent = M.normalize(parent_path)

  -- 确保父路径以斜杠结尾以避免误判
  if not parent:match('/$') then
    parent = parent .. '/'
  end

  return vim.startswith(child, parent)
end

---获取从文件到所有父目录的路径列表
---@param file_path string
---@param stop_fn fun(dir: string): boolean|nil 停止条件函数
---@param include_current boolean|nil 是否包含当前目录
---@return string[]
function M.list_parents(file_path, stop_fn, include_current)
  local paths = {}
  local current = M.normalize(file_path)

  -- 如果是文件，先获取父目录
  if M.is_file(current) then
    current = M.dirname(current)
  end

  if include_current and M.is_dir(current) then
    table.insert(paths, current)
  end

  while true do
    local parent = M.dirname(current)
    if parent == current or parent == '' then
      break
    end

    if stop_fn and stop_fn(parent) then
      table.insert(paths, parent)
      break
    end

    table.insert(paths, parent)
    current = parent
  end

  return paths
end

---获取相对路径
---@param path_str string
---@param base string|nil
---@return string
function M.relative(path_str, base)
  local target = M.normalize(path_str)
  local base_path = base and M.normalize(base) or vim.fn.getcwd()

  if vim.startswith(target, base_path) then
    return target:sub(#base_path + 2) -- +2 to skip the trailing slash
  end

  return target
end

return M
