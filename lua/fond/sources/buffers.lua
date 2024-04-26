local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.buffers", "debug")
local prefer = require("infra.prefer")
local project = require("infra.project")
local strlib = require("infra.strlib")

local aux = require("fond.sources.aux")

local uv = vim.loop
local api = vim.api

---@param root string
---@param bufnr integer
---@return string?
local function resolve_bufname(root, bufnr)
  if prefer.bo(bufnr, "buftype") ~= "" then return end
  local bufname = api.nvim_buf_get_name(bufnr)
  if bufname == "" then return end --eg, bufnr=1
  if strlib.find(bufname, "://") then return end

  local relative = fs.relative_path(root, bufname)
  return relative or bufname
end

---@type fond.Source
return function(fzf)
  assert(fzf ~= nil)

  local root = project.working_root()

  local dest_fpath = os.tmpname()
  local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
  if open_err ~= nil then return jelly.err(open_err) end

  local ok = aux.guarded_close(fd, function()
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
      local bufname = resolve_bufname(root, bufnr)
      if bufname ~= nil then
        uv.fs_write(fd, bufname)
        uv.fs_write(fd, "\n")
      end
    end
  end)

  if ok then return aux.guarded_call(fzf, dest_fpath, { pending_unlink = true }) end
end
