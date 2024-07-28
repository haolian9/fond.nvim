local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.siblings", "debug")
local subprocess = require("infra.subprocess")

local aux = require("fond.sources.aux")
local StdoutCollector = require("fond.sources.StdoutCollector")

-- stylua: ignore
local fd_args = {
  "--color=never",
  "--hidden",
  "--follow",
  "--strip-cwd-prefix",
  "--type", "f",
  "--max-depth", "1",
  "--exclude", ".git",
  "--max-results", "999",
}

---@type fond.CacheableSource
return function(use_cached_source, fzf)
  assert(fzf ~= nil and use_cached_source ~= nil)

  local root = vim.fn.expand("%:p:h")
  local dest_fpath = aux.resolve_dest_fpath(root, "siblings")
  if use_cached_source and fs.file_exists(dest_fpath) then return aux.guarded_call(fzf, dest_fpath, { pending_unlink = false }) end

  local collector = StdoutCollector()

  subprocess.spawn("fd", { args = fd_args, cwd = root }, collector.on_stdout, function(code)
    collector.write_to_file(dest_fpath)

    if code == 0 then return aux.guarded_call(fzf, dest_fpath, { pending_unlink = false }) end
    jelly.err("fd failed: exit code=%d", code)
  end)
end
