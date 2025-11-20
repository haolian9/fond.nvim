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
---@return integer,integer,string @row,col,text
local function normalize_choice(choice)
  local parts = strlib.iter_splits(choice, ",")
  local _ = assert(parts())
  local row = assert(tonumber(parts()))
  local col = assert(tonumber(parts()))
  local text = assert(parts())

  return row, col, text
end

local single = {
  ["ctrl-m"] = function(row, col)
    jumplist.push_here()
    wincursor.g1(0, row, col)
  end,
  ["ctrl-/"] = function(row, col)
    winsplit("right")
    wincursor.g1(0, row, col)
  end,
  ["ctrl-o"] = function(row, col)
    winsplit("below")
    wincursor.g1(0, row, col)
  end,
  ["ctrl-t"] = function(row, col)
    ex("tabedit", "%")
    wincursor.g1(0, row, col)
  end,
}

---@type {[string]: fun(act: fond.handlers.Act, iter: fun():integer,integer,string)} @iter(row,col,text)
local batch = {
  ["ctrl-f"] = function(act, iter)
    local winid = ni.get_current_win()
    local bufnr = ni.win_get_buf(winid)

    local shelf = sting.location.shelf(winid, act.ns)
    shelf:reset()
    for row, col, text in iter do
      shelf:append({ bufnr = bufnr, col = col, lnum = row, text = text })
    end
    shelf:feed_vim(true, true)
  end,
}

local act = Act("lsp_document_symbols", normalize_choice, single, batch)

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries.lsp_document_symbols = query

  act(action, choices)
end
