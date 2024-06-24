local itertools = require("infra.itertools")
local jelly = require("infra.jellyfish")("fond.handlers.Act", "debug")
local strlib = require("infra.strlib")

---design:
---* actions are mutual exclusive between .single and .batch
---* rather than the number of choices
---
---@class fond.handlers.Act
---@field ns string @namespace, currently for sting.quickfix.shelf
---@field private normalize_choice fun(choice: string): ...
---@field private single fun(...) @the signature depends on self.normalize_choice()
---@field private batch fun(iter: fun():any) @the `iter` arg is an iterator, what it returns depends on self.normalize_choice()
local Act = {}

Act.__index = Act

---@param action string
---@param choices string[]
function Act:__call(action, choices)
  local act

  act = self.batch[action]
  if act ~= nil then return act(self, itertools.map(choices, self.normalize_choice)) end

  act = self.single[action]
  if act ~= nil then return act(self.normalize_choice(assert(choices[1]))) end

  return jelly.warn("unexpected action %s for %s", action, self.ns)
end

---@param ns string
---@param normalize_choice fun(choice: string): ...
---@param single {[string]: fun(...)} @the function signature depends on self.normalize_choice()
---@param batch {[string]: fun(iter: fun())} @the `iter` arg is an iterator, what it returns depends on self.normalize_choice()
---@return fond.handlers.Act
return function(ns, normalize_choice, single, batch)
  if not strlib.startswith(ns, "fond:") then ns = string.format("fond:%s", ns) end
  return setmetatable({ ns = ns, normalize_choice = normalize_choice, single = single, batch = batch }, Act)
end
