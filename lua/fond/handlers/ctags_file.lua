local ex = require("infra.ex")
local jumplist = require("infra.jumplist")
local strlib = require("infra.strlib")
local wincursor = require("infra.wincursor")

local Act = require("fond.handlers.Act")
local state = require("fond.state")
local sting = require("sting")

local api = vim.api

---@param choice string
---@return integer,string
local function normalize_choice(choice)
  local text, row = string.match(choice, "(.*):(%d+)$")
  row = assert(tonumber(row))
  text = strlib.rstrip(text)
  return row, text
end

local single
do
  ---@param cmd string
  ---@param row integer
  local function main(cmd, row)
    jumplist.push_here()
    ex(cmd, "%")
    wincursor.g1(nil, row, 0)
  end

  single = {
    ["ctrl-/"] = function(row) main("vsplit", row) end,
    ["ctrl-o"] = function(row) main("split", row) end,
    ["ctrl-m"] = function(row) main("edit", row) end,
    ["ctrl-t"] = function(row) main("tabedit", row) end,
  }
end

---@type {[string]: fun(act: fond.handlers.Act, iter: fun():integer,string)} @iter(row,text)
local batch = {
  ["ctrl-f"] = function(act, iter)
    local winid = api.nvim_get_current_win()
    local bufnr = api.nvim_win_get_buf(winid)

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
