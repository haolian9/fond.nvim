local FileAct = require("fond.handlers.FileAct")
local state = require("fond.state")

local act = FileAct("git_status_files", function(choice)
  --it should start with a 3-length prefix: `?? ` or ` M ` or ` D ` ...
  assert(string.sub(choice, 3, 3) == " ")
  return string.sub(choice, 4)
end)

return function(query, action, choices)
  state.queries.git_status_files = query

  act(action, choices)
end
