---用户命令系统
---提供用户交互命令来管理虚拟环境
local venv = require('nvim-python-venv.venv')
local cache = require('nvim-python-venv.cache')
local managers = require('nvim-python-venv.managers')
local lsp = require('nvim-python-venv.lsp')
local logger = require('nvim-python-venv.common.logger')
local path = require('nvim-python-venv.common.path')

local M = {}

---选择并激活虚拟环境
---@param config Config
function M.select_venv(config)
  -- 获取所有可用的虚拟环境
  local venv_list = managers.get_all_venvs(config)

  if #venv_list == 0 then
    logger.warn('No virtual environments found')
    return
  end

  -- 准备选项列表
  local items = {}
  for _, item in ipairs(venv_list) do
    local display = string.format('[%s] %s', item.manager, item.path)
    table.insert(items, { path = item.path, display = display, manager = item.manager })
  end

  -- 使用 vim.ui.select 让用户选择
  vim.ui.select(items, {
    prompt = 'Select virtual environment:',
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if not choice then
      return
    end

    -- 激活选择的虚拟环境
    local success = venv.activate(choice.path, config)

    if success and config.auto_restart_lsp then
      lsp.restart_buffer_lsp()
    end
  end)
end

---手动添加虚拟环境映射
---@param config Config
function M.add_venv(config)
  -- 获取当前 buffer 的路径
  local bufnr = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(bufnr)

  if buf_name == '' then
    logger.error('Current buffer has no associated file')
    return
  end

  -- 查找可能的 root 目录
  local root_dir = venv.find_root_dir(buf_name)
  if not root_dir then
    root_dir = path.dirname(buf_name)
  end

  -- 让用户输入或确认 root_dir
  vim.ui.input({
    prompt = 'Project root directory: ',
    default = root_dir,
  }, function(input_root)
    if not input_root or input_root == '' then
      return
    end

    input_root = path.normalize(input_root)

    if not path.exists(input_root) then
      logger.error('Directory does not exist: ' .. input_root)
      return
    end

    -- 获取所有虚拟环境供用户选择
    local venv_list = managers.get_all_venvs(config)
    local items = {}

    for _, item in ipairs(venv_list) do
      local display = string.format('[%s] %s', item.manager, item.path)
      table.insert(items, { path = item.path, display = display })
    end

    -- 添加自定义路径选项
    table.insert(items, { path = '__custom__', display = '< Enter custom path >' })

    vim.ui.select(items, {
      prompt = 'Select virtual environment:',
      format_item = function(item)
        return item.display
      end,
    }, function(choice)
      if not choice then
        return
      end

      if choice.path == '__custom__' then
        -- 让用户输入自定义路径
        vim.ui.input({
          prompt = 'Virtual environment path: ',
          default = '',
        }, function(custom_path)
          if not custom_path or custom_path == '' then
            return
          end

          custom_path = path.normalize(custom_path)
          M.save_venv_mapping(input_root, custom_path, config)
        end)
      else
        M.save_venv_mapping(input_root, choice.path, config)
      end
    end)
  end)
end

---保存虚拟环境映射
---@param root_dir string
---@param venv_path string
---@param config Config
function M.save_venv_mapping(root_dir, venv_path, config)
  if not path.exists(venv_path) then
    logger.error('Virtual environment does not exist: ' .. venv_path)
    return
  end

  -- 获取元数据
  local metadata = managers.get_metadata(venv_path, nil, config)

  -- 保存到缓存
  cache.set_venv(root_dir, venv_path, metadata)

  logger.info(string.format('Saved mapping: %s -> %s', root_dir, venv_path))

  -- 重启相关 buffer 的 LSP
  if config.auto_restart_lsp then
    lsp.restart_root_lsp(root_dir)
  end
end

---移除虚拟环境映射
---@param config Config
function M.remove_venv(config)
  local all_venvs = cache.get_all_venvs()

  if vim.tbl_isempty(all_venvs) then
    logger.warn('No cached virtual environment mappings')
    return
  end

  local items = {}
  for root, venv_path in pairs(all_venvs) do
    table.insert(items, {
      root = root,
      venv = venv_path,
      display = string.format('%s -> %s', root, venv_path),
    })
  end

  vim.ui.select(items, {
    prompt = 'Remove mapping:',
    format_item = function(item)
      return item.display
    end,
  }, function(choice)
    if not choice then
      return
    end

    cache.set_venv(choice.root, nil)
    logger.info('Removed mapping: ' .. choice.display)
  end)
end

---刷新虚拟环境列表
---@param config Config
function M.refresh(config)
  -- 清空全局环境缓存
  managers.reset()

  logger.info('Virtual environment list refreshed')
end

---显示当前虚拟环境信息
function M.show_info()
  local info = venv.get_info()

  if not info then
    logger.info('No virtual environment is currently activated')
    return
  end

  local lines = {
    'Virtual Environment Information:',
    '  Path: ' .. info.path,
    '  Python: ' .. info.python_path,
    '  Version: ' .. info.python_version,
    '  Manager: ' .. info.manager_type,
    '  Active: ' .. (info.is_active and 'Yes' or 'No'),
  }

  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO, { title = 'Python Venv' })
end

---打开缓存文件
---@param config Config
function M.open_cache_file(config)
  vim.cmd.edit(config.cache.file_path)
end

---清空缓存
function M.clear_cache()
  cache.clear_all()
end

---注册所有用户命令
---@param config Config
function M.setup_commands(config)
  -- VenvSelect: 选择虚拟环境
  vim.api.nvim_create_user_command('VenvSelect', function()
    M.select_venv(config)
  end, { desc = 'Select and activate a virtual environment' })

  -- VenvActivate: 激活指定路径的虚拟环境
  vim.api.nvim_create_user_command('VenvActivate', function(opts)
    if not opts.args or opts.args == '' then
      logger.error('Usage: VenvActivate <venv_path>')
      return
    end
    local venv_path = path.normalize(opts.args)
    venv.activate(venv_path, config)
  end, { desc = 'Activate a virtual environment', nargs = 1, complete = 'dir' })

  -- VenvDeactivate: 停用虚拟环境
  vim.api.nvim_create_user_command('VenvDeactivate', function()
    venv.deactivate(config)
  end, { desc = 'Deactivate the current virtual environment' })

  -- VenvAdd: 添加虚拟环境映射
  vim.api.nvim_create_user_command('VenvAdd', function()
    M.add_venv(config)
  end, { desc = 'Add a virtual environment mapping' })

  -- VenvRemove: 移除虚拟环境映射
  vim.api.nvim_create_user_command('VenvRemove', function()
    M.remove_venv(config)
  end, { desc = 'Remove a virtual environment mapping' })

  -- VenvRefresh: 刷新虚拟环境列表
  vim.api.nvim_create_user_command('VenvRefresh', function()
    M.refresh(config)
  end, { desc = 'Refresh virtual environment list' })

  -- VenvInfo: 显示当前虚拟环境信息
  vim.api.nvim_create_user_command('VenvInfo', function()
    M.show_info()
  end, { desc = 'Show current virtual environment information' })

  -- VenvCacheOpen: 打开缓存文件
  vim.api.nvim_create_user_command('VenvCacheOpen', function()
    M.open_cache_file(config)
  end, { desc = 'Open the cache file' })

  -- VenvCacheClear: 清空缓存
  vim.api.nvim_create_user_command('VenvCacheClear', function()
    M.clear_cache()
  end, { desc = 'Clear the cache' })

  -- VenvLspRestart: 重启 Python LSP
  vim.api.nvim_create_user_command('VenvLspRestart', function()
    lsp.restart_buffer_lsp()
    logger.info('Python LSP restarted')
  end, { desc = 'Restart Python LSP for current buffer' })
end

return M
