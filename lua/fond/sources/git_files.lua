local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.git_files", "debug")
local project = require("infra.project")
local subprocess = require("infra.subprocess")

local aux = require("fond.sources.aux")

local uv = vim.loop

---@type fond.CacheableSource
return function(use_cached_source, fzf)
  local root = project.git_root()
  if root == nil then return jelly.info("not a git repo") end

  local dest_fpath = aux.resolve_dest_fpath(root, "git_files")
  if use_cached_source and fs.file_exists(dest_fpath) then return aux.guarded_call(fzf, dest_fpath, { pending_unlink = false }) end

  local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
  if open_err ~= nil then return jelly.err(open_err) end

  subprocess.spawn("git", { args = { "ls-files" }, cwd = root }, aux.LineWriter(fd), function(code)
    if code == 0 then return aux.guarded_call(fzf, dest_fpath, { pending_unlink = false }) end
    jelly.err("fd failed: exit code=%d", code)
  end)
end
