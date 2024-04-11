local FileAct = require("fond.handlers.FileAct")
local state = require("fond.state")

local act = FileAct("git_files", function(choice) return choice end)

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries.git_files = query

  act(action, choices)
end

