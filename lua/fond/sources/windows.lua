local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("fond.sources.windows", "debug")
local listlib = require("infra.listlib")

local infra = require("fond.sources.infra")

local api = vim.api
local uv = vim.loop

---@return fun(): string? @'winid,bufnr tabnr:winnr bufname'
local function source()
  local cur_tab = api.nvim_get_current_tabpage()
  local tab_iter = fn.filter(function(tabid) return tabid ~= cur_tab end, api.nvim_list_tabpages())
  local win_iter = nil
  local tabnr = nil

  return function()
    if win_iter == nil then
      local tab_id = tab_iter()
      if tab_id == nil then return end
      tabnr = api.nvim_tabpage_get_number(tab_id)
      win_iter = listlib.iter(api.nvim_tabpage_list_wins(tab_id))
    end
    for winid in win_iter do
      local bufnr = api.nvim_win_get_buf(winid)
      local winnr = api.nvim_win_get_number(winid)
      local bufname = api.nvim_buf_get_name(bufnr)
      return string.format("%d,%d %d,%d - %s", winid, bufnr, tabnr, winnr, bufname)
    end
  end
end

--purposes & implementation details:
--* share the same buffer
--* share the same window view: cursor, top/bot line
--* keep the original window unspoiled
--* cloned window does not inherit options, event&autocmd, variables from the original window
---@type fond.Source
return function(fzf)
  assert(fzf ~= nil)

  local dest_fpath = os.tmpname()
  local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
  if open_err ~= nil then return jelly.err(open_err) end

  local ok = infra.LineWriter(fd)(source())
  if ok then return infra.guarded_call(fzf, dest_fpath, { pending_unlink = true, with_nth = "2.." }) end
end
