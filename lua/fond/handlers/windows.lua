local ex = require("infra.ex")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("fzf.handlers.windows")
local prefer = require("infra.prefer")
local strlib = require("infra.strlib")

local Act = require("fond.handlers.Act")
local state = require("fond.state")

local api = vim.api

---@param choice string
---@return integer,integer @winid,bufnr
local function normalize_choice(choice)
  local plain = string.sub(choice, 1, strlib.find(choice, " ") - 1)
  local parts = fn.split(plain, ",", 1)
  local winid = assert(tonumber(parts[1]))
  local bufnr = assert(tonumber(parts[2]))
  return winid, bufnr
end

local single
do
  ---@param split 'vsplit'|'split'
  ---@param src_winid integer
  ---@param src_bufnr integer
  local function main(split, src_winid, src_bufnr)
    local src_view
    local src_wo = {}
    api.nvim_win_call(src_winid, function() src_view = vim.fn.winsaveview() end)
    for _, opt in ipairs({ "list" }) do
      src_wo[opt] = prefer.wo(src_winid, opt)
    end

    ex(split)

    local winid = api.nvim_get_current_win()
    api.nvim_win_set_buf(winid, src_bufnr)
    vim.fn.winrestview(src_view)
    for opt, val in pairs(src_wo) do
      prefer.wo(winid, opt, val)
    end
  end

  single = {
    ["ctrl-/"] = function(src_winid, src_bufnr) main("vsplit", src_winid, src_bufnr) end,
    ["ctrl-o"] = function(src_winid, src_bufnr) main("split", src_winid, src_bufnr) end,
    ["ctrl-m"] = function(src_winid, src_bufnr) main("vsplit", src_winid, src_bufnr) end,
    ["ctrl-t"] = function(_) return jelly.warn("unexpected action <c-t>") end,
  }
end

local batch = {
  ["ctrl-f"] = function() return jelly.warn("unexpected action <c-f>") end,
}

local act = Act("windows", normalize_choice, single, batch)

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries.windows = query

  act(action, choices)
end
