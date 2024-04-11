local ex = require("infra.ex")
local fn = require("infra.fn")
local jumplist = require("infra.jumplist")

local Act = require("fond.handlers.Act")
local state = require("fond.state")
local sting = require("sting")

local api = vim.api

---@param choice string
---@return string,integer,integer,string @fpath,row,col,text
local function normalize_choice(choice)
  local parts = fn.split_iter(choice, ",")
  local fpath = assert(parts())
  local row = assert(tonumber(parts()))
  local col = assert(tonumber(parts()))
  local text = assert(parts())

  return fpath, row, col, text
end

local single
do
  ---@param cmd string
  ---@param row integer
  ---@param col integer
  local function main(cmd, fpath, row, col)
    jumplist.push_here()
    ex(cmd, fpath)
    api.nvim_win_set_cursor(0, { row, col })
  end

  single = {
    ["ctrl-/"] = function(fpath, row, col) main("vsplit", fpath, row, col) end,
    ["ctrl-o"] = function(fpath, row, col) main("split", fpath, row, col) end,
    ["ctrl-m"] = function(fpath, row, col) main("edit", fpath, row, col) end,
    ["ctrl-t"] = function(fpath, row, col) main("tabedit", fpath, row, col) end,
  }
end

---@type {[string]: fun(act: fond.handlers.Act, iter: fun():string,integer,integer,string)} @iter(fpath,row,col,text)
local batch = {
  ["ctrl-f"] = function(act, iter)
    local shelf = sting.quickfix.shelf(act.ns)
    shelf:reset()
    for fpath, lnum, col, text in iter do
      local row = lnum + 1
      shelf:append({ filename = fpath, col = col, lnum = row, text = text })
    end
    shelf:feed_vim(true, true)
  end,
}

local act = Act("lsp_workspace_symbols", normalize_choice, single, batch)

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries.lsp_workspace_symbols = query

  act(action, choices)
end
