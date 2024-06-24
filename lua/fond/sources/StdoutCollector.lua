local itertools = require("infra.itertools")
local iuv = require("infra.iuv")
local jelly = require("infra.jellyfish")("fond.sources.StdoutCollector", "info")
local subprocess = require("infra.subprocess")

---@class fond.sources.StdoutCollector
---@field on_stdout fun(data?: string)
---@field write_to_file fun(fpath: string, format_line?: fun(line: string): string)

---@return fond.sources.StdoutCollector
return function()
  local closed = false
  local chunks = {}

  return {
    ---@param data? string
    on_stdout = function(data)
      if data then return table.insert(chunks, data) end
      closed = true
    end,
    ---@param fpath string
    ---@param format_line? fun(line: string): string
    write_to_file = function(fpath, format_line)
      assert(closed, "try to write down incomplete stdout")

      local fd, open_err = iuv.fs_open(fpath, "w", tonumber("600", 8))
      if open_err ~= nil then error(open_err) end

      local iter = subprocess.iter_lines(chunks)
      if format_line then iter = itertools.map(iter, format_line) end

      for line in iter do
        iuv.fs_write(fd, line)
        iuv.fs_write(fd, "\n")
      end

      iuv.fs_close(fd)
    end,
  }
end
