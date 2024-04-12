local buflines = require("infra.buflines")
local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("fzf.handlers.olds")
local jumplist = require("infra.jumplist")

local Act = require("fond.handlers.Act")
local state = require("fond.state")
local sting = require("sting")

local api = vim.api

---@param choice string
local function normalize_choice(choice)
  local path, lnum, col = string.match(choice, "^(.+):(%d+):(%d+)$")
  lnum = tonumber(lnum)
  col = tonumber(col)
  assert(path and lnum and col)

  return path, lnum, col
end

local single
do
  ---@param cmd string
  ---@param lnum integer
  ---@param col integer
  local function main(cmd, fpath, lnum, col)
    jumplist.push_here()

    ex(cmd, fpath)

    do --goto that position
      jelly.debug("path=%s, line=%d, col=%d", fpath, lnum, col)
      local winid = api.nvim_get_current_win()
      local row_max = buflines.count(api.nvim_win_get_buf(winid))
      local row = lnum + 1
      if row <= row_max then
        api.nvim_win_set_cursor(winid, { row, col })
      else
        jelly.warn("goto last line, as #%d line no longer exists", lnum)
        api.nvim_win_set_cursor(winid, { row_max, col })
      end
    end
  end

  single = {
    ["ctrl-/"] = function(fpath, lnum, col) main("vsplit", fpath, lnum, col) end,
    ["ctrl-o"] = function(fpath, lnum, col) main("split", fpath, lnum, col) end,
    ["ctrl-m"] = function(fpath, lnum, col) main("edit", fpath, lnum, col) end,
    ["ctrl-t"] = function(fpath, lnum, col) main("tabedit", fpath, lnum, col) end,
  }
end

---@type {[string]: fun(act: fond.handlers.Act, iter: fun():string,integer,integer)} @iter(fpath,row,col)
local batch = {
  ["ctrl-f"] = function(act, iter)
    local shelf = sting.quickfix.shelf(act.ns)
    shelf:reset()
    for fpath, lnum, col in iter do
      local row = lnum + 1
      shelf:append({ filename = fpath, col = col, lnum = row, text = "" })
    end
    shelf:feed_vim(true, true)
  end,
}

local act = Act("olds", normalize_choice, single, batch)

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries["olds"] = query

  act(action, choices)
end
