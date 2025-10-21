---缓存系统模块
---提供三层缓存架构：L1 内存缓存、L2 持久化文件缓存、L3 全局环境缓存
local path = require('nvim-python-venv.common.path')
local logger = require('nvim-python-venv.common.logger')

local M = {}

local uv = vim.uv or vim.loop

---@class CacheData
---@field root_to_venv table<string, string> root_dir -> venv_path 映射
---@field venv_metadata table<string, VenvMetadata> venv_path -> 元数据映射
---@field last_updated number 最后更新时间戳

---@class VenvMetadata
---@field python_version string Python 版本
---@field manager_type string 管理器类型
---@field last_access number 最后访问时间
---@field packages_count number|nil 包数量（可选）

-- L1: 内存缓存（当前会话）
M._memory_cache = {
  root_to_venv = {}, -- root_dir -> venv_path
  venv_metadata = {}, -- venv_path -> metadata
  global_venvs = {}, -- manager_name -> venv_list
}

-- L2: 文件缓存状态
M._file_cache_loaded = false
M._pending_write = false

-- L3: 全局环境缓存
M._global_cache = {}

---读取 JSON 文件缓存
---@param file_path string
---@return CacheData|nil
local function read_cache_file(file_path)
  local normalized = path.normalize(file_path)
  if not path.exists(normalized) then
    return nil
  end

  local fd = uv.fs_open(normalized, 'r', 438) -- 0666
  if not fd then
    logger.error('Failed to open cache file: ' .. normalized)
    return nil
  end

  local stat = uv.fs_fstat(fd)
  if not stat then
    uv.fs_close(fd)
    return nil
  end

  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)

  if not data then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, data, { luanil = { object = true, array = true } })
  if not ok or type(decoded) ~= 'table' then
    logger.warn('Failed to decode cache file: ' .. normalized)
    return nil
  end

  return decoded
end

---写入 JSON 文件缓存（异步）
---@param file_path string
---@param data CacheData
---@param callback fun(success: boolean, error: string|nil)|nil
local function write_cache_file_async(file_path, data, callback)
  callback = callback or function() end

  local normalized = path.normalize(file_path)

  -- 确保父目录存在
  local success, err = path.ensure_dir(path.dirname(normalized))
  if not success then
    callback(false, err)
    return
  end

  -- 序列化数据
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    callback(false, 'Failed to encode cache data')
    return
  end

  -- 异步写入
  uv.fs_open(normalized, 'w', 438, function(err_open, fd) -- 0666
    if err_open or not fd then
      callback(false, 'Failed to open cache file for writing: ' .. (err_open or 'unknown'))
      return
    end

    uv.fs_write(fd, encoded, 0, function(err_write)
      uv.fs_close(fd, function() end)

      if err_write then
        callback(false, 'Failed to write cache file: ' .. err_write)
      else
        callback(true, nil)
      end
    end)
  end)
end

---防抖写入缓存文件
---@param config Config
local function debounced_write_cache(config)
  if M._pending_write then
    return
  end

  M._pending_write = true

  vim.defer_fn(function()
    M._pending_write = false

    if not config.cache.enabled then
      return
    end

    local cache_data = {
      root_to_venv = M._memory_cache.root_to_venv,
      venv_metadata = M._memory_cache.venv_metadata,
      last_updated = os.time(),
    }

    write_cache_file_async(config.cache.file_path, cache_data, function(success, error_msg)
      if not success then
        logger.error('Failed to write cache: ' .. (error_msg or 'unknown error'))
      end
    end)
  end, 500)
end

---初始化缓存系统
---@param config Config
function M.init(config)
  if M._file_cache_loaded then
    return
  end

  if not config.cache.enabled then
    M._file_cache_loaded = true
    return
  end

  -- 确保缓存文件存在
  path.ensure_file(config.cache.file_path)

  -- 读取持久化缓存
  local cache_data = read_cache_file(config.cache.file_path)
  if cache_data then
    M._memory_cache.root_to_venv = cache_data.root_to_venv or {}
    M._memory_cache.venv_metadata = cache_data.venv_metadata or {}

    -- 清理无效缓存
    if config.cache.auto_clean then
      M.clean_invalid_entries()
    end
  end

  M._file_cache_loaded = true
end

---获取虚拟环境路径
---@param root_dir string
---@return string|nil
function M.get_venv(root_dir)
  local normalized = path.normalize(root_dir)
  return M._memory_cache.root_to_venv[normalized]
end

---设置虚拟环境路径
---@param root_dir string
---@param venv_path string|nil
---@param metadata VenvMetadata|nil
function M.set_venv(root_dir, venv_path, metadata)
  local config = require('nvim-python-venv.config').get()
  local normalized_root = path.normalize(root_dir)

  if venv_path then
    local normalized_venv = path.normalize(venv_path)
    M._memory_cache.root_to_venv[normalized_root] = normalized_venv

    -- 保存元数据
    if metadata then
      metadata.last_access = os.time()
      M._memory_cache.venv_metadata[normalized_venv] = metadata
    end
  else
    -- 移除缓存
    M._memory_cache.root_to_venv[normalized_root] = nil
  end

  -- 防抖写入文件
  debounced_write_cache(config)
end

---获取虚拟环境元数据
---@param venv_path string
---@return VenvMetadata|nil
function M.get_metadata(venv_path)
  local normalized = path.normalize(venv_path)
  return M._memory_cache.venv_metadata[normalized]
end

---更新虚拟环境元数据
---@param venv_path string
---@param metadata VenvMetadata
function M.update_metadata(venv_path, metadata)
  local config = require('nvim-python-venv.config').get()
  local normalized = path.normalize(venv_path)

  metadata.last_access = os.time()
  M._memory_cache.venv_metadata[normalized] = metadata

  debounced_write_cache(config)
end

---根据文件名查找 root_dir
---@param file_name string
---@return string|nil
function M.find_root_by_file(file_name)
  local normalized = path.normalize(file_name)

  for root_dir, _ in pairs(M._memory_cache.root_to_venv) do
    if path.is_subpath(normalized, root_dir) then
      return root_dir
    end
  end

  return nil
end

---获取所有缓存的虚拟环境
---@return table<string, string>
function M.get_all_venvs()
  return vim.deepcopy(M._memory_cache.root_to_venv)
end

---清理无效的缓存条目
function M.clean_invalid_entries()
  local config = require('nvim-python-venv.config').get()
  local cleaned_count = 0

  -- 清理不存在的虚拟环境
  for root_dir, venv_path in pairs(M._memory_cache.root_to_venv) do
    if not path.exists(venv_path) then
      M._memory_cache.root_to_venv[root_dir] = nil
      M._memory_cache.venv_metadata[venv_path] = nil
      cleaned_count = cleaned_count + 1
    end
  end

  if cleaned_count > 0 then
    logger.debug(string.format('Cleaned %d invalid cache entries', cleaned_count))
    debounced_write_cache(config)
  end
end

---清空所有缓存
function M.clear_all()
  M._memory_cache.root_to_venv = {}
  M._memory_cache.venv_metadata = {}
  M._memory_cache.global_venvs = {}

  local config = require('nvim-python-venv.config').get()
  debounced_write_cache(config)

  logger.info('Cache cleared')
end

---内存缓存包装器（用于全局环境列表等）
---@generic T
---@param key string
---@param fn fun(): T
---@return T
function M.with_memory_cache(key, fn)
  if M._memory_cache.global_venvs[key] ~= nil then
    return M._memory_cache.global_venvs[key]
  end

  local result = fn()
  M._memory_cache.global_venvs[key] = result
  return result
end

---重置特定键的内存缓存
---@param key string
function M.reset_memory_cache(key)
  M._memory_cache.global_venvs[key] = nil
end

return M
