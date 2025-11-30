local bufopen = require("infra.bufopen")
local jelly = require("infra.jellyfish")("fzf.handlers.olds")
local jumplist = require("infra.jumplist")
local mi = require("infra.mi")
local wincursor = require("infra.wincursor")

local Act = require("fond.handlers.Act")
local state = require("fond.state")
local sting = require("sting")

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
  local function safe_goto(winid, lnum, col)
    winid = mi.resolve_winid_param(winid)
    --ignore error: 'Cursor position outside buffer'
    pcall(wincursor.g0, winid, lnum, col)
  end

  single = {
    ["ctrl-m"] = function(fpath, lnum, col)
      jumplist.push_here()

      bufopen.inplace(fpath)
      safe_goto(0, lnum, col)
    end,
    ["ctrl-/"] = function(fpath, lnum, col)
      bufopen.right(fpath)
      safe_goto(0, lnum, col)
    end,
    ["ctrl-o"] = function(fpath, lnum, col)
      bufopen.below(fpath)
      safe_goto(0, lnum, col)
    end,
    ["ctrl-t"] = function(fpath, lnum, col)
      bufopen.tab(fpath)
      safe_goto(0, lnum, col)
    end,
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
