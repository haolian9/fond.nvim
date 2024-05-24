local M = {}

local cthulhu = require("cthulhu")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.aux", "debug")

local facts = require("fond.facts")

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

return M
