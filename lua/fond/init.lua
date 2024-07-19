-- design choice
-- * sourcer -> file
-- * file -> fzf -> stdout (maybe)
-- * no app abstract: {state, source, handler}; it's over complicated, bloating the code base
-- * no hard limit for singleton: in my practice, it's over complicated to use mutexes in the callback-based async codes
-- * always need a tmpfile
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

local M = {}

---@param name string
local function cachable_provider(name)
  ---@param use_cached_source ?boolean
  ---@param use_last_query ?boolean
  return function(use_cached_source, use_last_query)
    local state = require("fond.state")
    local fzf = require("fond.fzf")

    ---@type fond.CacheableSource
    local source = require(string.format("fond.sources.%s", name))
    ---@type fond.fzf.Handler
    local handler = require(string.format("fond.handlers.%s", name))

    if use_cached_source == nil then use_cached_source = true end
    if use_last_query == nil then use_last_query = true end
    local last_query = use_last_query and state.queries[name] or nil

    source(use_cached_source, function(src_fpath, fzf_opts)
      vim.schedule(function() fzf(name, src_fpath, last_query, handler, fzf_opts) end)
    end)
  end
end

---@param name string
local function fresh_provider(name)
  ---@param use_last_query ?boolean
  return function(use_last_query)
    local state = require("fond.state")
    local fzf = require("fond.fzf")

    ---@type fond.Source
    local source = require(string.format("fond.sources.%s", name))
    ---@type fond.fzf.Handler
    local handler = require(string.format("fond.handlers.%s", name))

    if use_last_query == nil then use_last_query = true end
    local last_query = use_last_query and state.queries[name] or nil

    source(function(src_fpath, fzf_opts)
      vim.schedule(function() fzf(name, src_fpath, last_query, handler, fzf_opts) end)
    end)
  end
end

M.files = cachable_provider("files")
M.siblings = cachable_provider("siblings")
M.tracked = cachable_provider("git_files")
M.document_symbols = cachable_provider("lsp_document_symbols")
M.olds = cachable_provider("olds")
M.ctags = cachable_provider("ctags_file")
M.helps = cachable_provider("helps")

M.modified = fresh_provider("git_modified_files")
M.statuses = fresh_provider("git_status_files")

return M
