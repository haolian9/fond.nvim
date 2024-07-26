local Act = require("fond.handlers.Act")
local state = require("fond.state")
local help = require("helphelp")

local act
do
  local function normalize_choice(choice) return choice end

  local single = {
    ["ctrl-m"] = function(subject) help("inplace", subject) end,
    ["ctrl-/"] = function(subject) help("right", subject) end,
    ["ctrl-o"] = function(subject) help("below", subject) end,
    ["ctrl-t"] = function(subject) help("tab", subject) end,
  }

  local batch = {}

  act = Act("helps", normalize_choice, single, batch)
end

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries.helps = query

  act(action, choices)
end
