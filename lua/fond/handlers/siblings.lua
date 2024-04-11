local fs = require("infra.fs")

local FileAct = require("fond.handlers.FileAct")
local state = require("fond.state")

local act = FileAct("siblings", function(choice) return fs.joinpath(vim.fn.expand("%:p:h"), choice) end)

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries.siblings = query

  act(action, choices)
end

