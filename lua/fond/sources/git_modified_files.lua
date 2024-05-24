local jelly = require("infra.jellyfish")("fond.sources.git_modified_files", "debug")
local project = require("infra.project")
local subprocess = require("infra.subprocess")

local aux = require("fond.sources.aux")
local StdoutCollector = require("fond.sources.StdoutCollector")

---@type fond.Source
return function(fzf)
  local root = project.git_root()
  if root == nil then return jelly.info("not a git repo") end

  local dest_fpath = os.tmpname()
  local collector = StdoutCollector()

  subprocess.spawn("git", { args = { "ls-files", "--modified" }, cwd = root }, collector.on_stdout, function(code)
    collector.write_to_file(dest_fpath)

    if code == 0 then return aux.guarded_call(fzf, dest_fpath, { pending_unlink = true }) end
    jelly.err("fd failed: exit code=%d", code)
  end)
end
