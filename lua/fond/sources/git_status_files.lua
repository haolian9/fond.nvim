local jelly = require("infra.jellyfish")("fond.sources.git_status_files", "debug")
local project = require("infra.project")
local subprocess = require("infra.subprocess")

local aux = require("fond.sources.aux")

local uv = vim.loop

---@type fond.Source
return function(fzf)
  local root = project.git_root()
  if root == nil then return jelly.info("not a git repo") end

  local dest_fpath = os.tmpname()
  local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
  if open_err ~= nil then return jelly.err(open_err) end

  subprocess.spawn("git", { args = { "status", "--porcelain=v1" }, cwd = root }, aux.LineWriter(fd), function(code)
    if code == 0 then return aux.guarded_call(fzf, dest_fpath, { pending_unlink = true }) end
    jelly.err("fd failed: exit code=%d", code)
  end)
end
