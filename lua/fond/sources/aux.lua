local M = {}

local cthulhu = require("cthulhu")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.files", "debug")

local facts = require("fond.facts")

local uv = vim.loop

---@param path string @absolute path
---@param use_for string
---@return string
function M.resolve_dest_fpath(path, use_for)
  assert(path and use_for)
  local name = string.format("%s-%s", use_for, cthulhu.md5(path))
  return fs.joinpath(facts.root, name)
end

function M.guarded_call(f, ...)
  local ok, err = xpcall(f, debug.traceback, ...)
  if not ok then jelly.err(err) end
end

---@param fd number
---@param f fun()
---@return boolean
function M.guarded_close(fd, f)
  local ok, err = xpcall(f, debug.traceback)
  uv.fs_close(fd)
  if not ok then jelly.warn(err) end
  return ok
end

---@param fd number
---@return fun(lines: fun(): string?): boolean
function M.LineWriter(fd)
  return function(lines)
    return M.guarded_close(fd, function()
      for line in lines do
        uv.fs_write(fd, line)
        uv.fs_write(fd, "\n")
      end
    end)
  end
end

return M
