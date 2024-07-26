local fs = require("infra.fs")
local iuv = require("infra.iuv")
local jelly = require("infra.jellyfish")("fond.sources.helps", "debug")
local strlib = require("infra.strlib")

local aux = require("fond.sources.aux")

---@type fond.CacheableSource
return function(use_cached_source, fzf)
  local fzf_opts = { pending_unlink = false }

  local src_fpath
  do
    local rt = os.getenv("VIMRUNTIME")
    assert(rt ~= nil and rt ~= "")
    src_fpath = fs.joinpath(rt, "doc/tags")
  end

  local dest_fpath = aux.resolve_dest_fpath(src_fpath, "helps")
  if use_cached_source and fs.file_exists(dest_fpath) then return aux.guarded_call(fzf, dest_fpath, fzf_opts) end

  do
    local fd, open_err = iuv.fs_open(dest_fpath, "w", tonumber("600", 8))
    if open_err ~= nil then return jelly.err(open_err) end
    for line in io.lines(src_fpath) do
      local subject = strlib.iter_splits(line, "\t")()
      assert(subject ~= nil and subject ~= "")
      iuv.fs_write(fd, subject)
      iuv.fs_write(fd, "\n")
    end
    iuv.fs_close(fd)
  end

  return aux.guarded_call(fzf, dest_fpath, fzf_opts)
end
