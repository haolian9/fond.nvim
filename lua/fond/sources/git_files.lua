local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.git_files", "debug")
local project = require("infra.project")
local subprocess = require("infra.subprocess")

local aux = require("fond.sources.aux")
local StdoutCollector = require("fond.sources.StdoutCollector")

---@type fond.CacheableSource
return function(use_cached_source, fzf)
  local root = project.git_root()
  if root == nil then return jelly.info("not a git repo") end

  local dest_fpath = aux.resolve_dest_fpath(root, "git_files")
  if use_cached_source and fs.file_exists(dest_fpath) then return aux.guarded_call(fzf, dest_fpath, { pending_unlink = false }) end

  local collector = StdoutCollector()

  subprocess.spawn("git", { args = { "ls-files" }, cwd = root }, collector.on_stdout, function(code)
    collector.write_to_file(dest_fpath)

    if code == 0 then return aux.guarded_call(fzf, dest_fpath, { pending_unlink = false }) end
    jelly.err("fd failed: exit code=%d", code)
  end)
end
