---Shell 命令执行工具模块
local M = {}

local uv = vim.uv or vim.loop

---同步执行 shell 命令
---@param cmd string|string[] 命令或命令数组
---@param opts table|nil 选项 { cwd: string, timeout: number }
---@return boolean success 是否成功
---@return string|nil output 命令输出
---@return string|nil error 错误信息
function M.execute(cmd, opts)
  opts = opts or {}

  local cmd_str
  if type(cmd) == 'table' then
    cmd_str = table.concat(cmd, ' ')
  else
    cmd_str = cmd
  end

  -- 添加错误重定向
  cmd_str = cmd_str .. ' 2>&1'

  local result = vim.fn.system(cmd_str)
  local exit_code = vim.v.shell_error

  if exit_code == 0 then
    -- 移除尾部空白
    result = result:gsub('%s+$', '')
    return true, result, nil
  else
    return false, nil, result
  end
end

---异步执行 shell 命令
---@param cmd string|string[] 命令或命令数组
---@param opts table|nil 选项 { cwd: string, env: table }
---@param callback fun(success: boolean, output: string|nil, error: string|nil) 回调函数
function M.execute_async(cmd, opts, callback)
  opts = opts or {}

  local cmd_array
  if type(cmd) == 'string' then
    cmd_array = { 'sh', '-c', cmd }
  else
    cmd_array = cmd
  end

  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local stdout_data = {}
  local stderr_data = {}

  local handle, pid
  handle, pid = uv.spawn(
    cmd_array[1],
    {
      args = vim.list_slice(cmd_array, 2),
      stdio = { nil, stdout, stderr },
      cwd = opts.cwd,
      env = opts.env,
    },
    vim.schedule_wrap(function(code, signal)
      stdout:close()
      stderr:close()
      handle:close()

      local output = table.concat(stdout_data, '')
      local error = table.concat(stderr_data, '')

      if code == 0 then
        callback(true, output:gsub('%s+$', ''), nil)
      else
        callback(false, nil, error:gsub('%s+$', ''))
      end
    end)
  )

  if not handle then
    callback(false, nil, 'Failed to spawn process')
    return
  end

  stdout:read_start(function(err, data)
    if err then
      return
    end
    if data then
      table.insert(stdout_data, data)
    end
  end)

  stderr:read_start(function(err, data)
    if err then
      return
    end
    if data then
      table.insert(stderr_data, data)
    end
  end)
end

---检查命令是否可执行
---@param cmd string
---@return boolean
function M.is_executable(cmd)
  return vim.fn.executable(cmd) == 1
end

---快速检查命令是否存在（不执行）
---@param cmd string
---@return boolean
function M.has_command(cmd)
  return M.is_executable(cmd)
end

return M
