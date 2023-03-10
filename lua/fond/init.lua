-- design choice
-- * sourcer -> file
-- * file -> fzf -> stdout (maybe)
-- * no app abstract: {state, source, handler}; it's over complicated, bloating the code base
--
-- file structures
-- * state: {queries: {sourcer: query}}
-- * fzf: fn(src_fpath, last_query, handler, pending_unlink=false)
-- * sources: sourcer(..., handler) src_fpath
-- * handlers: handler(query, action, choices) void
--
-- formats:
-- * file: [fpath]
--    * git tracked files, git changed files, fd, mru file
-- * buffer position: [{bufname, bufnr, col, line, text}]
--    * rg, git grep
--    * lsp symbol
--    * treesitter tokens
--
-- todo: avoid unnecessary tmpfile for buffers
-- todo: mutex, in my practice, it's over complicated to impl in the callback-based async codes
-- todo: alternative MRU source: `find $root -type f -newermt '1 weeks ago'`
--

local M = {}

local fzf = require("fond.fzf")
local sources = require("fond.sources")
local handlers = require("fond.handlers")
local state = require("fond.state")

local function cachable_provider(srcname)
  local source = assert(sources[srcname])
  local handler = assert(handlers[srcname])

  ---@param use_cached_source ?boolean
  ---@param use_last_query ?boolean
  return function(use_cached_source, use_last_query)
    if use_cached_source == nil then use_cached_source = true end
    if use_last_query == nil then use_last_query = true end
    local last_query = use_last_query and state.queries[srcname] or nil

    source(use_cached_source, function(src_fpath, fzf_opts)
      vim.schedule(function()
        fzf(src_fpath, last_query, handler, fzf_opts)
      end)
    end)
  end
end

local function fresh_provider(srcname)
  local source = assert(sources[srcname])
  local handler = assert(handlers[srcname])

  return function()
    source(function(src_fpath, fzf_opts)
      vim.schedule(function()
        fzf(src_fpath, nil, handler, fzf_opts)
      end)
    end)
  end
end

M.files = cachable_provider("files")
M.siblings = cachable_provider("siblings")
M.tracked = cachable_provider("git_files")
M.symbols = cachable_provider("lsp_symbols")

M.mru = fresh_provider("mru")
M.buffers = fresh_provider("buffers")
M.modified = fresh_provider("git_modified_files")
M.windows = fresh_provider("windows")

return M
