local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.olds", "debug")

local infra = require("fond.sources.infra")

---@type fond.CacheableSource
return function(use_cached_source, fzf)
  assert(fzf ~= nil)

  local ok, olds = pcall(require, "olds")
  if not ok then error(olds) end

  local dest_fpath = infra.resolve_dest_fpath("nvim", "olds")
  if not (use_cached_source and fs.file_exists(dest_fpath)) then
    if not olds.dump(dest_fpath) then return jelly.err("failed to dump oldfiles") end
  end

  return infra.guarded_call(fzf, dest_fpath, { pending_unlink = false })
end
