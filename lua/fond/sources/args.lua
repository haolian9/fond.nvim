local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("fond.sources.args", "debug")

local aux = require("fond.sources.aux")

local uv = vim.loop

---@type fond.Source
return function(fzf)
  local args = {}
  --no matter it's global or win-local
  --todo: more efficient way
  for i = 0, vim.fn.argc() - 1 do
    table.insert(args, vim.fn.argv(i))
  end
  if #args == 0 then return jelly.info("empty win-local arglist") end

  local dest_fpath = os.tmpname()
  local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
  if open_err ~= nil then return jelly.err(open_err) end

  local ok = aux.LineWriter(fd)(fn.iter(args))
  if ok then return aux.guarded_call(fzf, dest_fpath, { pending_unlink = true }) end
end
