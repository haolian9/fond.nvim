local fs = require("infra.fs")
local project = require("infra.project")
local strlib = require("infra.strlib")

local FileAct = require("fond.handlers.FileAct")
local state = require("fond.state")

local act = FileAct("buffers", function(choice)
  if strlib.startswith(choice, "/") then return choice end
  return fs.joinpath(project.working_root(), choice)
end)

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries.buffers = query

  act(action, choices)
end
