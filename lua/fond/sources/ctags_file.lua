local bufpath = require("infra.bufpath")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.ctags", "debug")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local subprocess = require("infra.subprocess")

local aux = require("fond.sources.aux")
local StdoutCollector = require("fond.sources.StdoutCollector")

--nvim's &ft to ctags's language
--`$ ctags --print-language %f`
local ft_to_lang = {
  lua = "Lua",
  python = "Python",
  c = "C",
  bash = "Sh",
  sh = "Sh",
  go = "Go",
  vim = "Vim",
  markdown = "Markdown",
  php = "PHP",
}

--see `ctags --list-kinds-full`
local kind_to_symbol = {
  ["function"] = "函",
  member = "函",
  struct = "構",
  class = "構",
  module = "構",
  unknown = "佚",
  default = "無",
}

--see `ctags --list-fields=NONE`
local fields = table.concat({
  "+n", --line number
  "-F", --input file
  "-P", --pattern
  --
  "+K", --kind of tag, long-name
  "+Z", --same as s/field
  "+k", --kind of tag, short-name
  "+p", --kind of scope, long-name
  "+s", --name of scope
  "+z", --kind, long-name
  --
  "+E", --extra tag type
  "+S", --signature
  "-T", --input file's modified time
}, "")

---@class fond.Ctag
---@field _type 'tag'
---@field name string
---@field line integer
---@field kind 'function'|any
---@field scope? string
---@field scopeKind? 'unknown'|any

---@param line string
---@return string
local function normalize_line(line)
  ---@type fond.Ctag
  local tag = vim.json.decode(line)
  assert(tag._type == "tag", tag._type)

  local symbol = kind_to_symbol[tag.kind] or kind_to_symbol.default

  local name = tag.name
  if tag.scope ~= nil then name = string.format("%s.%s", tag.scope, tag.name) end

  return string.format("%s %s :%s", symbol, name, tag.line)
end

---@type fond.CacheableSource
return function(use_cached_source, fzf)
  local fzf_opts = { pending_unlink = false }

  local bufnr = ni.get_current_buf()

  local lang = ft_to_lang[prefer.bo(bufnr, "filetype")]
  if lang == nil then return jelly.warn("unsupported filetype") end

  local fpath = assert(bufpath.file(bufnr))

  local dest_fpath = aux.resolve_dest_fpath(fpath, "ctags_file")
  if use_cached_source and fs.file_exists(dest_fpath) then return aux.guarded_call(fzf, dest_fpath, fzf_opts) end

  local ctags_args = {
    "-o-",
    "--languages=" .. lang,
    "--fields=" .. fields,
    "--output-format=json",
    "--sort=no",
    fs.basename(fpath),
  }

  local collector = StdoutCollector()

  subprocess.spawn("ctags", { args = ctags_args, cwd = fs.parent(fpath) }, collector.on_stdout, function(code)
    collector.write_to_file(dest_fpath, normalize_line)
    if code == 0 then return aux.guarded_call(fzf, dest_fpath, fzf_opts) end
    jelly.err("ctags failed: exit code=%d", code)
  end)
end
