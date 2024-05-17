local ex = require("infra.ex")
local jelly = require("infra.jellyfish")("fond.handlers.args", "debug")

local Act = require("fond.handlers.Act")
local state = require("fond.state")

---@param choice string
---@return string
local function normalize_choice(choice) return choice end

local single
do
  ---@param arg string
  local function main(arg) ex.cmd("edit", arg) end

  single = {
    ["ctrl-/"] = main,
    ["ctrl-o"] = main,
    ["ctrl-m"] = main,
    ["ctrl-t"] = main,
  }
end

local batch = {
  ["ctrl-f"] = function() return jelly.warn("nonsense action <c-f>") end,
  ["ctrl-g"] = function() return jelly.warn("nonsense action <c-g>") end,
}

local act = Act("args", normalize_choice, single, batch)

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries.args = query

  act(action, choices)
end
