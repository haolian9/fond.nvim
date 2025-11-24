local M = {}

local itertools = require("infra.itertools")
local logging = require("infra.logging")
local strlib = require("infra.strlib")

local log = logging.newlogger("fond.LspSymbolResolver", "info")

---@enum
local symbols = {
  Function = "函",
  Method = "函",
  Struct = "構",
  Class = "構",
  Property = "属",
  default = "無",
}

---@alias Kind 'Function'|'Method'|'Struct'|'Class'
---@alias Item {col: number, lnum: number, kind: Kind, filename: string, text: string}

-- resolver: fn(items) string
-- * items: [{col, lnum, kind, filename, text}]; see lsp-on-list-handler
-- * return string: "{filename},{row},{col}, {symbol} {text}"
--
-- when the result not satisfies you, changes those resolver according to the `vim.lsp.buf.document_symbol()`
--
---@alias Resolver fun(items: Item[]): fun(): string?

---@param item Item
---@return string
local function naked_text(item) return string.sub(item.text, #item.kind + #"[] " + 1) end

---@param item Item
---@param symbol? string
---@return string
local function normalize_line(item, symbol)
  if symbol == nil then symbol = symbols[item.kind] or symbols.default end
  local text = naked_text(item)
  local row = item.lnum
  local col = item.col - 1

  return string.format("%s,%s,%s, %s %s", item.filename, row, col, symbol, text)
end

---@param line_resolver fun(item: Item): string?
local function resolve_items(line_resolver)
  ---@param items Item[]
  ---@return fun(): string?
  return function(items)
    local iter = itertools.iter(items)

    return function()
      for item in iter do
        local line = line_resolver(item)
        if line ~= nil then return line end
      end
    end
  end
end

---@type Resolver
M.lua = resolve_items(function(item)
  log.debug("lua symbol: %s", item)
  local symbol
  if item.kind == "Variable" then
    -- no: bare variable
    if not strlib.contains(item.text, ".") then return end
    -- yes: m.var
    symbol = symbols.Property
  elseif item.kind == "Function" then
    -- no: anonymous function
    if item.text == "[Function] return" then return end
    -- yes: named function
    symbol = symbols.Function
  elseif item.kind == "Method" then
    -- yes: method
    symbol = symbols.Method
  elseif item.kind == "Object" then
    -- yes: class
    symbol = symbols.Class
  else
    return -- no: all others
  end

  return normalize_line(item, symbol)
end)

M.c = resolve_items(function(item)
  if item.kind == "Struct" or item.kind == "Class" then
    -- no: anony struct
    if strlib.endswith(item.text, "(anonymous struct)") then return end
  elseif item.kind == "Enum" then
    -- no: anony enum
    if strlib.endswith(item.text, "(anonymous enum)") then return end
  elseif item.kind == "Function" then
  else
    -- Field, Variable
    return
  end
  return normalize_line(item)
end)

M.zig = resolve_items(function(item)
  local symbol
  if item.kind == "Function" then
  elseif item.kind == "Struct" or item.kind == "Enum" then
  elseif item.kind == "Variable" then
    -- yes: const Type = struct {}
    if string.find(naked_text(item), "^%u") == nil then return end
    symbol = symbols.Struct
  else
    -- Variable, Field
    return
  end
  return normalize_line(item, symbol)
end)

M.python = resolve_items(function(item)
  if item.kind == "Function" or item.kind == "Method" then
  elseif item.kind == "Class" then
  else
    return
  end
  return normalize_line(item)
end)

M.go = resolve_items(function(item)
  if item.kind == "Function" or item.kind == "Method" then
  elseif item.kind == "Struct" then
  else
    return
  end
  return normalize_line(item)
end)

return M
