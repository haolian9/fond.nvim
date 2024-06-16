local bufpath = require("infra.bufpath")
local fs = require("infra.fs")
local iuv = require("infra.iuv")
local jelly = require("infra.jellyfish")("fond.sources.lsp_document_symbols", "debug")
local ni = require("infra.ni")
local prefer = require("infra.prefer")

local aux = require("fond.sources.aux")
local LspSymbolResolver = require("fond.sources.LspSymbolResolver")

---persistent cache files are good for browsering codebases
---@type fond.CacheableSource
return function(use_cached_source, fzf)
  local fzf_opts = { pending_unlink = false, with_nth = "2.." }

  local resolver, fpath
  do
    local bufnr = ni.get_current_buf()
    local ft = prefer.bo(bufnr, "filetype")
    resolver = LspSymbolResolver[ft]
    if resolver == nil then return jelly.info("no symbol handler found for %s", ft) end
    fpath = assert(bufpath.file(bufnr))
  end

  local dest_fpath = aux.resolve_dest_fpath(fpath, "lsp_document_symbols")
  if use_cached_source and fs.file_exists(dest_fpath) then return aux.guarded_call(fzf, dest_fpath, fzf_opts) end

  vim.lsp.buf.document_symbol({
    on_list = function(args)
      local fd, open_err = iuv.fs_open(dest_fpath, "w", tonumber("600", 8))
      if open_err ~= nil then return jelly.err(open_err) end
      for line in resolver(args.items) do
        iuv.fs_write(fd, line)
        iuv.fs_write(fd, "\n")
      end
      iuv.fs_close(fd)

      return aux.guarded_call(fzf, dest_fpath, fzf_opts)
    end,
  })
end
