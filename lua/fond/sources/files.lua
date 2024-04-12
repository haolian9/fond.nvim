local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.files", "debug")
local project = require("infra.project")
local subprocess = require("infra.subprocess")

local infra = require("fond.sources.infra")

local uv = vim.loop

-- stylua: ignore
local fd_args = {
  "--color=never",
  "--hidden",
  "--follow",
  "--strip-cwd-prefix",
  "--type", "f",
  "--exclude", ".git",
}

---@type fond.CacheableSource
return function(use_cached_source, fzf)
  assert(fzf ~= nil and use_cached_source ~= nil)

  local root = project.working_root()

  local dest_fpath = infra.resolve_dest_fpath(root, "files")
  if use_cached_source and fs.file_exists(dest_fpath) then return infra.guarded_call(fzf, dest_fpath, { pending_unlink = false }) end

  local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
  if open_err ~= nil then error(open_err) end

  subprocess.spawn("fd", { args = fd_args, cwd = root }, infra.LineWriter(fd), function(code)
    if code == 0 then return infra.guarded_call(fzf, dest_fpath, { pending_unlink = false }) end
    jelly.err("fd failed: exit code=%d", code)
  end)
end
