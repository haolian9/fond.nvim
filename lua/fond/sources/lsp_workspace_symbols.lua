local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.lsp_workspace_symbols", "debug")
local prefer = require("infra.prefer")
local project = require("infra.project")

local aux = require("fond.sources.aux")
local LspSymbolResolver = require("fond.sources.LspSymbolResolver")

local api = vim.api
local uv = vim.loop

---@type fond.CacheableSource
return function(use_cached_source, fzf)
  local fzf_opts = { pending_unlink = false, with_nth = "2.." }

  local resolver, fpath
  do
    local bufnr = api.nvim_get_current_buf()
    local ft = prefer.bo(bufnr, "filetype")
    resolver = LspSymbolResolver[ft]
    if resolver == nil then return jelly.info("no symbol handler found for %s", ft) end
    fpath = string.format("%s@%s", assert(project.git_root()), ft)
  end

  local dest_fpath = aux.resolve_dest_fpath(fpath, "lsp_workspace_symbols")
  if use_cached_source and fs.file_exists(dest_fpath) then return aux.guarded_call(fzf, dest_fpath, fzf_opts) end

  local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
  if open_err ~= nil then return jelly.err(open_err) end

  vim.lsp.buf.workspace_symbol("", {
    on_list = function(args)
      local ok = aux.LineWriter(fd)(resolver(args.items))
      if ok then return aux.guarded_call(fzf, dest_fpath, fzf_opts) end
    end,
  })
end

