---基础测试示例
---使用 plenary.nvim 进行测试

local eq = assert.are.same

describe('nvim-python-venv', function()
  local venv

  before_each(function()
    -- 重新加载模块
    package.loaded['nvim-python-venv'] = nil
    package.loaded['nvim-python-venv.config'] = nil
    package.loaded['nvim-python-venv.cache'] = nil

    venv = require('nvim-python-venv')
  end)

  describe('setup', function()
    it('可以使用默认配置初始化', function()
      local ok = pcall(venv.setup)
      assert.is_true(ok)
    end)

    it('可以使用自定义配置初始化', function()
      local ok = pcall(venv.setup, {
        auto_detect = false,
        cache = {
          enabled = false,
        },
      })
      assert.is_true(ok)
    end)
  end)

  describe('path utilities', function()
    local path = require('nvim-python-venv.common.path')

    it('可以规范化路径', function()
      local normalized = path.normalize('/path/to/dir/')
      eq('/path/to/dir', normalized)
    end)

    it('可以连接路径', function()
      local joined = path.join('/path', 'to', 'file.txt')
      eq('/path/to/file.txt', joined)
    end)

    it('可以获取父目录', function()
      local parent = path.dirname('/path/to/file.txt')
      eq('/path/to', parent)
    end)

    it('可以获取文件名', function()
      local basename = path.basename('/path/to/file.txt')
      eq('file.txt', basename)
    end)
  end)

  describe('managers', function()
    local managers = require('nvim-python-venv.managers')

    it('可以加载所有管理器', function()
      local config = require('nvim-python-venv.config').get()
      local venv_path, manager_type = managers.auto_detect('/tmp/test-project', config)
      -- 没有实际项目，应该返回 nil
      assert.is_nil(venv_path)
      assert.is_nil(manager_type)
    end)
  end)

  describe('cache', function()
    local cache = require('nvim-python-venv.cache')
    local config = require('nvim-python-venv.config')

    before_each(function()
      -- 使用临时缓存文件
      config.update({
        cache = {
          enabled = true,
          file_path = '/tmp/nvim-python-venv-test-cache.json',
        },
      })
      cache.init(config.get())
    end)

    it('可以保存和读取虚拟环境映射', function()
      cache.set_venv('/project/root', '/project/.venv', {
        python_version = '3.11',
        manager_type = 'local_venv',
        last_access = os.time(),
      })

      local venv_path = cache.get_venv('/project/root')
      eq('/project/.venv', venv_path)
    end)

    it('可以清空缓存', function()
      cache.set_venv('/project/root', '/project/.venv')
      cache.clear_all()

      local venv_path = cache.get_venv('/project/root')
      assert.is_nil(venv_path)
    end)
  end)
end)
