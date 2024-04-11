local ex = require("infra.ex")

local Act = require("fond.handlers.Act")
local sting = require("sting")

local single = {
  ["ctrl-/"] = function(file) ex("vsplit", file) end,
  ["ctrl-o"] = function(file) ex("split", file) end,
  ["ctrl-m"] = function(file) ex("edit", file) end,
  ["ctrl-t"] = function(file) ex("tabedit", file) end,
}

---@type {[string]: fun(act: fond.handlers.Act, files: fun(): string?)}
local batch = {
  ["ctrl-f"] = function(act, files)
    local shelf = sting.quickfix.shelf(act.ns)
    shelf:reset()
    for file in files do
      --todo: what's the better value?
      shelf:append({ filename = file, col = 1, lnum = 1, text = "" })
    end
    shelf:feed_vim(true, true)
  end,
  --todo: ctrl-a for :args?
}

---@param ns string @namespace; could be used for string.quickfix.shelf
---@param normalize_choice fun(choice: string): string
return function(ns, normalize_choice) return Act(ns, normalize_choice, single, batch) end
