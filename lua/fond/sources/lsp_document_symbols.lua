local bufpath = require("infra.bufpath")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fond.sources.lsp_document_symbols", "debug")
local prefer = require("infra.prefer")

local infra = require("fond.sources.infra")
local LspSymbolResolver = require("fond.sources.LspSymbolResolver")

local api = vim.api
local uv = vim.loop

---persistent cache files are good for browsering codebases
---@type fond.CacheableSource
return function(use_cached_source, fzf)
  local fzf_opts = { pending_unlink = false, with_nth = "2.." }

  local resolver, fpath
  do
    local bufnr = api.nvim_get_current_buf()
    local ft = prefer.bo(bufnr, "filetype")
    resolver = LspSymbolResolver[ft]
    if resolver == nil then return jelly.info("no symbol handler found for %s", ft) end
    fpath = assert(bufpath.file(bufnr))
  end

  local dest_fpath = infra.resolve_dest_fpath(fpath, "lsp_document_symbols")
  if use_cached_source and fs.file_exists(dest_fpath) then return infra.guarded_call(fzf, dest_fpath, fzf_opts) end

  local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
  if open_err ~= nil then return jelly.err(open_err) end

  vim.lsp.buf.document_symbol({
    on_list = function(args)
      local ok = infra.LineWriter(fd)(resolver(args.items))
      if ok then return infra.guarded_call(fzf, dest_fpath, fzf_opts) end
    end,
  })
end