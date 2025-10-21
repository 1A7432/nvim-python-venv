---虚拟环境管理器基础接口定义
---所有虚拟环境管理器必须实现此接口
local M = {}

---@class VenvManagerInterface
---@field name string 管理器名称（例如：'poetry', 'conda'）
---@field priority number 优先级（数字越小优先级越高）
---@field is_available fun(): boolean 检查管理器是否可用（可执行文件是否存在）
---@field is_project_venv fun(root_dir: string): boolean 判断项目是否使用该管理器
---@field get_project_venv fun(root_dir: string): string|nil 获取项目的虚拟环境路径
---@field get_global_venvs fun(): string[] 获取全局虚拟环境列表
---@field get_metadata fun(venv_path: string): VenvMetadata|nil 获取虚拟环境元数据

---创建一个虚拟环境管理器基类
---@param name string
---@param priority number
---@return VenvManagerInterface
function M.create_base(name, priority)
  return {
    name = name,
    priority = priority or 100,

    ---默认实现：检查可用性（子类应重写）
    is_available = function()
      return false
    end,

    ---默认实现：判断是否为项目虚拟环境（子类应重写）
    is_project_venv = function(root_dir)
      return false
    end,

    ---默认实现：获取项目虚拟环境（子类应重写）
    get_project_venv = function(root_dir)
      return nil
    end,

    ---默认实现：获取全局虚拟环境列表（子类应重写）
    get_global_venvs = function()
      return {}
    end,

    ---默认实现：获取虚拟环境元数据
    get_metadata = function(venv_path)
      local os_utils = require('nvim-python-venv.common.os')
      local shell = require('nvim-python-venv.common.shell')
      local path_utils = require('nvim-python-venv.common.path')

      local python_path = os_utils.get_python_executable(venv_path)
      if not path_utils.exists(python_path) then
        return nil
      end

      -- 获取 Python 版本
      local success, output = shell.execute(python_path .. ' --version')
      local python_version = 'unknown'
      if success and output then
        python_version = output:match('Python%s+([%d%.]+)') or 'unknown'
      end

      return {
        python_version = python_version,
        manager_type = name,
        last_access = os.time(),
      }
    end,
  }
end

return M
