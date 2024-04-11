local ex = require("infra.ex")
local fn = require("infra.fn")
local jumplist = require("infra.jumplist")

local Act = require("fond.handlers.Act")
local state = require("fond.state")
local sting = require("sting")

local api = vim.api

---@param choice string
---@return integer,integer,string @row,col,text
local function normalize_choice(choice)
  local parts = fn.split_iter(choice, ",")
  local _ = assert(parts())
  local row = assert(tonumber(parts()))
  local col = assert(tonumber(parts()))
  local text = assert(parts())

  return row, col, text
end

local single
do
  ---@param cmd string
  ---@param row integer
  ---@param col integer
  local function main(cmd, row, col)
    jumplist.push_here()
    ex(cmd, "%")
    api.nvim_win_set_cursor(0, { row, col })
  end

  single = {
    ["ctrl-/"] = function(row, col) main("vsplit", row, col) end,
    ["ctrl-o"] = function(row, col) main("split", row, col) end,
    ["ctrl-m"] = function(row, col) main("edit", row, col) end,
    ["ctrl-t"] = function(row, col) main("tabedit", row, col) end,
  }
end

---@type {[string]: fun(act: fond.handlers.Act, iter: fun():integer,integer,string)} @iter(row,col,text)
local batch = {
  ["ctrl-f"] = function(act, iter)
    local winid = api.nvim_get_current_win()
    local bufnr = api.nvim_win_get_buf(winid)

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
