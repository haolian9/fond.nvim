-- resolver: fn(items) string
-- * items: [{col, lnum, kind, filename, text}]; see lsp-on-list-handler
-- * return string: "{row},{col} {symbol} {text}"
--
-- when the result not satisfies you, changes those resolver according to the `vim.lsp.buf.document_symbol()`
--

local fn = require("infra.fn")
--local jelly = require("infra.jellyfish")("fond.sources.lsp_symbols")

local symbols = {
  Function = "函",
  -- todo: more accurate name; python function, method;
  -- why some lang server do not include the class name in the response text?
  Method = "函",
  Struct = "構",
  Class = "構",
  default = "無",
}

local function naked_text(item)
  return string.sub(item.text, #item.kind + #"[] " + 1)
end

-- item: {col, lnum, kind, filename, text}
local function normalize_line(item, symbol)
  if symbol == nil then symbol = symbols[item.kind] or symbols.default end
  local text = naked_text(item)
  return string.format("%s,%s %s %s", item.lnum, item.col, symbol, text)
end

local function resolve_items(line_resolver)
  return function(items)
    local iter = fn.list_iter(items)

    return function()
      for item in iter do
        local line = line_resolver(item)
        if line ~= nil then return line end
      end
    end
  end
end

local function lua(item)
  local symbol
  if item.kind == "Variable" then
    -- ok: M.foo
    if string.find(item.text, ".", 1, true) == nil then return end
    symbol = symbols.Function
  elseif item.kind == "Function" then
    -- no: anonymous function
    if vim.endswith(item.text, "->") then return end
  else
    -- no: whitelist only
    return
  end

  return normalize_line(item, symbol)
end

local function c(item)
  if item.kind == "Struct" or item.kind == "Class" then
    -- no: anony struct
    if vim.endswith(item.text, "(anonymous struct)") then return end
  elseif item.kind == "Enum" then
    -- no: anony enum
    if vim.endswith(item.text, "(anonymous enum)") then return end
  elseif item.kind == "Function" then
  else
    -- Field, Variable
    return
  end
  return normalize_line(item)
end

local function zig(item)
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
end

local function python(item)
  if item.kind == "Function" or item.kind == "Method" then
  elseif item.kind == "Class" then
  else
    return
  end
  return normalize_line(item)
end

local function go(item)
  if item.kind == "Function" or item.kind == "Method" then
  elseif item.kind == "Struct" then
  else
    return
  end
  return normalize_line(item)
end

return {
  lua = resolve_items(lua),
  c = resolve_items(c),
  zig = resolve_items(zig),
  python = resolve_items(python),
  go = resolve_items(go),
}
