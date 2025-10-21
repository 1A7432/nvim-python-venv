---虚拟环境管理器统一入口
---负责加载、管理和协调所有虚拟环境管理器
local M = {}

local managers = nil
local sorted_managers = nil

---延迟加载所有管理器
---@return VenvManagerInterface[]
local function load_managers()
  if managers then
    return managers
  end

  managers = {
    require('nvim-python-venv.managers.uv'),
    require('nvim-python-venv.managers.poetry'),
    require('nvim-python-venv.managers.pipenv'),
    require('nvim-python-venv.managers.conda'),
    require('nvim-python-venv.managers.pyenv'),
    require('nvim-python-venv.managers.local_venv'),
    require('nvim-python-venv.managers.virtualenvwrapper'),
  }

  return managers
end

---获取按优先级排序的可用管理器
---@param config Config
---@return VenvManagerInterface[]
local function get_sorted_managers(config)
  if sorted_managers then
    return sorted_managers
  end

  local all_managers = load_managers()
  local enabled_managers = {}

  -- 过滤启用的管理器
  for _, manager in ipairs(all_managers) do
    if config.managers.enabled[manager.name] and manager.is_available() then
      table.insert(enabled_managers, manager)
    end
  end

  -- 按配置的优先级排序
  local priority_map = {}
  for i, name in ipairs(config.managers.priority) do
    priority_map[name] = i
  end

  table.sort(enabled_managers, function(a, b)
    local priority_a = priority_map[a.name] or 999
    local priority_b = priority_map[b.name] or 999
    return priority_a < priority_b
  end)

  sorted_managers = enabled_managers
  return sorted_managers
end

---重置管理器缓存（配置变更时调用）
function M.reset()
  managers = nil
  sorted_managers = nil
end

---自动检测项目的虚拟环境
---@param root_dir string
---@param config Config
---@return string|nil venv_path
---@return string|nil manager_type
function M.auto_detect(root_dir, config)
  local managers_list = get_sorted_managers(config)

  for _, manager in ipairs(managers_list) do
    if manager.is_project_venv(root_dir) then
      local venv_path = manager.get_project_venv(root_dir)
      if venv_path then
        return venv_path, manager.name
      end
    end
  end

  return nil, nil
end

---获取所有可用的虚拟环境列表
---@param config Config
---@return table[] 虚拟环境列表，每项包含 {path: string, manager: string}
function M.get_all_venvs(config)
  local managers_list = get_sorted_managers(config)
  local all_venvs = {}
  local seen = {}

  for _, manager in ipairs(managers_list) do
    local venvs = manager.get_global_venvs()
    for _, venv_path in ipairs(venvs) do
      if not seen[venv_path] then
        seen[venv_path] = true
        table.insert(all_venvs, {
          path = venv_path,
          manager = manager.name,
        })
      end
    end
  end

  return all_venvs
end

---获取特定虚拟环境的元数据
---@param venv_path string
---@param manager_name string|nil
---@param config Config
---@return VenvMetadata|nil
function M.get_metadata(venv_path, manager_name, config)
  local managers_list = load_managers()

  if manager_name then
    -- 使用指定的管理器
    for _, manager in ipairs(managers_list) do
      if manager.name == manager_name then
        return manager.get_metadata(venv_path)
      end
    end
  end

  -- 尝试所有管理器
  for _, manager in ipairs(managers_list) do
    local metadata = manager.get_metadata(venv_path)
    if metadata then
      return metadata
    end
  end

  return nil
end

---获取指定管理器
---@param name string
---@return VenvManagerInterface|nil
function M.get_manager(name)
  local managers_list = load_managers()
  for _, manager in ipairs(managers_list) do
    if manager.name == name then
      return manager
    end
  end
  return nil
end

return M
