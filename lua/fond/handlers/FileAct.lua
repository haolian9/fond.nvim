local bufopen = require("infra.bufopen")
local ex = require("infra.ex")
local itertools = require("infra.itertools")
local jumplist = require("infra.jumplist")

local Act = require("fond.handlers.Act")
local sting = require("sting")

local single = {
  ["ctrl-m"] = function(file)
    jumplist.push_here()
    bufopen("inplace", file)
  end,
  ["ctrl-/"] = function(file) bufopen("right", file) end,
  ["ctrl-o"] = function(file) bufopen("below", file) end,
  ["ctrl-t"] = function(file) bufopen("tab", file) end,
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
  ["ctrl-g"] = function(_, files)
    --todo: need to make files relatived to pwd?
    ex("arglocal", unpack(itertools.tolist(files)))
  end,
}

---@param ns string @namespace; could be used for string.quickfix.shelf
---@param normalize_choice fun(choice: string): string
return function(ns, normalize_choice) return Act(ns, normalize_choice, single, batch) end
