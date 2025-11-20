local ex = require("infra.ex")
local jumplist = require("infra.jumplist")
local ni = require("infra.ni")
local strlib = require("infra.strlib")
local wincursor = require("infra.wincursor")
local winsplit = require("infra.winsplit")

local Act = require("fond.handlers.Act")
local state = require("fond.state")
local sting = require("sting")

---@param choice string
---@return integer,string
local function normalize_choice(choice)
  local text, row = string.match(choice, "(.*):(%d+)$")
  row = assert(tonumber(row))
  text = strlib.rstrip(text)
  return row, text
end

local single = {
  ["ctrl-m"] = function(row)
    jumplist.push_here()
    wincursor.g1(0, row, 0)
  end,
  ["ctrl-/"] = function(row)
    winsplit("right")
    wincursor.g1(0, row, 0)
  end,
  ["ctrl-o"] = function(row)
    winsplit("below")
    wincursor.g1(0, row, 0)
  end,
  ["ctrl-t"] = function(row)
    ex("tabedit", "%")
    wincursor.g1(0, row, 0)
  end,
}

---@type {[string]: fun(act: fond.handlers.Act, iter: fun():integer,string)} @iter(row,text)
local batch = {
  ["ctrl-f"] = function(act, iter)
    local winid = ni.get_current_win()
    local bufnr = ni.win_get_buf(winid)

    local shelf = sting.location.shelf(winid, act.ns)
    shelf:reset()
    for row, text in iter do
      shelf:append({ bufnr = bufnr, col = 1, lnum = row, text = text })
    end
    shelf:feed_vim(true, true)
  end,
}

local act = Act("ctags_file", normalize_choice, single, batch)

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries.ctags_file = query

  act(action, choices)
end
