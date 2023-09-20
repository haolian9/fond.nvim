local M = {}

local cthulhu = require("cthulhu")
local bufpath = require("infra.bufpath")
local fn = require("infra.fn")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fzf.sources")
local listlib = require("infra.listlib")
local prefer = require("infra.prefer")
local project = require("infra.project")
local strlib = require("infra.strlib")
local subprocess = require("infra.subprocess")

local facts = require("fond.facts")
local lsp_symbol_resolver = require("fond.lsp_symbol_resolver")

local uv = vim.loop
local api = vim.api

---@alias fond.Source fun(callback: fun(dest_fpath: string, fzf_opts: fond.fzf.Opts))
---@alias fond.CacheableSource fun(use_cached_source: boolean, callback: fun(dest_fpath: string, fzf_opts: fond.fzf.Opts))

---@param path string @absolute path
---@param use_for string
---@return string
local function resolve_dest_fpath(path, use_for)
  assert(path and use_for)
  local name = string.format("%s-%s", use_for, cthulhu.md5(path))
  return fs.joinpath(facts.root, name)
end

local function guarded_callback(callback, ...)
  local ok, err = xpcall(callback, debug.traceback, ...)
  if not ok then vim.schedule(function() jelly.err(err) end) end
end

---@param fd number
---@param callback fun()
---@return boolean
local function guarded_close(fd, callback)
  local ok, err = xpcall(callback, debug.traceback)
  uv.fs_close(fd)
  if not ok then vim.schedule(function() jelly.warn(err) end) end
  return ok
end

---@param fd number
---@return fun(lines: string[]|(fun(): string[]?)): boolean
local function LineWriter(fd)
  return function(lines)
    return guarded_close(fd, function()
      for line in lines do
        uv.fs_write(fd, line)
        uv.fs_write(fd, "\n")
      end
    end)
  end
end

do -- filesystem relevant
  ---@type fond.CacheableSource
  function M.files(use_cached_source, callback)
    assert(callback ~= nil and use_cached_source ~= nil)

    local root = project.working_root()
    if root == nil then return end

    local dest_fpath = resolve_dest_fpath(root, "files")
    if use_cached_source and fs.exists(dest_fpath) then return guarded_callback(callback, dest_fpath, { pending_unlink = false }) end

    local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
    if open_err ~= nil then error(open_err) end

    -- stylua: ignore
    local fd_args = {
      "--color=never",
      "--hidden",
      "--follow",
      "--strip-cwd-prefix",
      "--type", "f",
      "--exclude", ".git",
    }

    subprocess.spawn("fd", { args = fd_args, cwd = root }, LineWriter(fd), function(code)
      if code == 0 then return guarded_callback(callback, dest_fpath, { pending_unlink = false }) end
      jelly.err("fd failed: exit code=%d", code)
    end)
  end

  ---@type fond.CacheableSource
  function M.siblings(use_cached_source, callback)
    assert(callback ~= nil and use_cached_source ~= nil)

    local root = vim.fn.expand("%:p:h")
    local dest_fpath = resolve_dest_fpath(root, "siblings")
    if use_cached_source and fs.exists(dest_fpath) then return guarded_callback(callback, dest_fpath, { pending_unlink = false }) end

    -- stylua: ignore
    local fd_args = {
      "--color=never",
      "--hidden",
      "--follow",
      "--strip-cwd-prefix",
      "--type", "f",
      "--max-depth", "1",
      "--exclude", ".git",
    }

    local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
    if open_err ~= nil then error(open_err) end

    subprocess.spawn("fd", { args = fd_args, cwd = root }, LineWriter(fd), function(code)
      if code == 0 then return guarded_callback(callback, dest_fpath, { pending_unlink = false }) end
      jelly.err("fd failed: exit code=%d", code)
    end)
  end
end

do -- git relevant
  ---@type fond.CacheableSource
  function M.git_files(use_cached_source, callback)
    local root = project.git_root()
    if root == nil then return jelly.info("not a git repo") end

    local dest_fpath = resolve_dest_fpath(root, "gitfiles")
    if use_cached_source and fs.exists(dest_fpath) then return guarded_callback(callback, dest_fpath, { pending_unlink = false }) end

    local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
    if open_err ~= nil then return jelly.err(open_err) end

    subprocess.spawn("git", { args = { "ls-files" }, cwd = root }, LineWriter(fd), function(code)
      if code == 0 then return guarded_callback(callback, dest_fpath, { pending_unlink = false }) end
      jelly.err("fd failed: exit code=%d", code)
    end)
  end

  ---@type fond.Source
  function M.git_modified_files(callback)
    local root = project.git_root()
    if root == nil then return jelly.info("not a git repo") end

    local dest_fpath = os.tmpname()
    local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
    if open_err ~= nil then return jelly.err(open_err) end

    subprocess.spawn("git", { args = { "ls-files", "--modified" }, cwd = root }, LineWriter(fd), function(code)
      if code == 0 then return guarded_callback(callback, dest_fpath, { pending_unlink = true }) end
      jelly.err("fd failed: exit code=%d", code)
    end)
  end

  ---@type fond.Source
  function M.git_status_files(callback)
    local root = project.git_root()
    if root == nil then return jelly.info("not a git repo") end

    local dest_fpath = os.tmpname()
    local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
    if open_err ~= nil then return jelly.err(open_err) end

    subprocess.spawn("git", { args = { "status", "--porcelain=v1" }, cwd = root }, LineWriter(fd), function(code)
      if code == 0 then return guarded_callback(callback, dest_fpath, { pending_unlink = true }) end
      jelly.err("fd failed: exit code=%d", code)
    end)
  end
end

do -- vim relevant
  ---@type fond.Source
  function M.buffers(callback)
    assert(callback ~= nil)

    local root = project.working_root()

    local function resolve_bufname(bufnr)
      if prefer.bo(bufnr, "buftype") ~= "" then return end
      local bufname = api.nvim_buf_get_name(bufnr)
      if bufname == "" then return end --eg, bufnr=1
      if strlib.find(bufname, "://") then return end

      local relative = fs.relative_path(root, bufname)
      return relative or bufname
    end

    local dest_fpath = os.tmpname()
    local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
    if open_err ~= nil then return jelly.err(open_err) end

    local ok = guarded_close(fd, function()
      for _, bufnr in ipairs(api.nvim_list_bufs()) do
        local bufname = resolve_bufname(bufnr)
        if bufname ~= nil then
          uv.fs_write(fd, bufname)
          uv.fs_write(fd, "\n")
        end
      end
    end)

    if ok then return guarded_callback(callback, dest_fpath, { pending_unlink = true }) end
  end

  ---@type fond.CacheableSource
  function M.olds(use_cached_source, callback)
    assert(callback ~= nil)

    local ok, olds = pcall(require, "olds")
    if not ok then error(olds) end

    local dest_fpath = resolve_dest_fpath("nvim", "olds")
    if not (use_cached_source and fs.exists(dest_fpath)) then
      if not olds.dump(dest_fpath) then return jelly.err("failed to dump oldfiles") end
    end

    return guarded_callback(callback, dest_fpath, { pending_unlink = false })
  end

  ---@type fond.Source
  function M.windows(callback)
    -- purposes & implementation details:
    -- * share the same buffer
    -- * share the same window view: cursor, top/bot line
    -- * keep the original window unspoiled
    -- * cloned window does not inherit options, event&autocmd, variables from the original window
    --

    assert(callback ~= nil)
    local function source()
      local cur_tab = api.nvim_get_current_tabpage()
      local tab_iter = fn.filter(function(tabid) return tabid ~= cur_tab end, api.nvim_list_tabpages())
      local win_iter = nil
      local tabnr = nil

      return function()
        if win_iter == nil then
          local tab_id = tab_iter()
          if tab_id == nil then return end
          tabnr = api.nvim_tabpage_get_number(tab_id)
          win_iter = listlib.iter(api.nvim_tabpage_list_wins(tab_id))
        end
        for winid in win_iter do
          local bufnr = api.nvim_win_get_buf(winid)
          local winnr = api.nvim_win_get_number(winid)
          local bufname = api.nvim_buf_get_name(bufnr)
          -- winid,bufnr tabnr:winnr bufname
          return string.format("%d,%d %d,%d - %s", winid, bufnr, tabnr, winnr, bufname)
        end
      end
    end

    local dest_fpath = os.tmpname()
    local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
    if open_err ~= nil then return jelly.err(open_err) end
    -- (winid,bufnr bufname)
    local ok = LineWriter(fd)(source())
    if ok then return guarded_callback(callback, dest_fpath, { pending_unlink = true, with_nth = "2.." }) end
  end
end

do -- lsp relevant
  ---persistent cache files are good for browsering codebases
  ---@type fond.CacheableSource
  function M.lsp_document_symbols(use_cached_source, callback)
    local fzf_opts = { pending_unlink = false, with_nth = "2.." }

    local resolver, fpath
    do
      local bufnr = api.nvim_get_current_buf()
      local ft = prefer.bo(bufnr, "filetype")
      resolver = lsp_symbol_resolver[ft]
      if resolver == nil then return jelly.info("no symbol handler found for %s", ft) end
      fpath = assert(bufpath.file(bufnr))
    end

    local dest_fpath = resolve_dest_fpath(fpath, "lsp_document_symbols")
    if use_cached_source and fs.exists(dest_fpath) then return guarded_callback(callback, dest_fpath, fzf_opts) end

    local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
    if open_err ~= nil then return jelly.err(open_err) end

    vim.lsp.buf.document_symbol({
      on_list = function(args)
        local ok = LineWriter(fd)(resolver(args.items))
        if ok then return guarded_callback(callback, dest_fpath, fzf_opts) end
      end,
    })
  end

  ---@type fond.CacheableSource
  function M.lsp_workspace_symbols(use_cached_source, callback)
    local fzf_opts = { pending_unlink = false, with_nth = "2.." }

    local resolver
    local fpath
    do
      local bufnr = api.nvim_get_current_buf()
      local ft = prefer.bo(bufnr, "filetype")
      resolver = lsp_symbol_resolver[ft]
      if resolver == nil then return jelly.info("no symbol handler found for %s", ft) end
      fpath = string.format("%s@%s", assert(project.git_root()), ft)
    end

    local dest_fpath = resolve_dest_fpath(fpath, "lsp_workspace_symbols")
    if use_cached_source and fs.exists(dest_fpath) then return guarded_callback(callback, dest_fpath, fzf_opts) end

    local fd, open_err = uv.fs_open(dest_fpath, "w", tonumber("600", 8))
    if open_err ~= nil then return jelly.err(open_err) end

    vim.lsp.buf.workspace_symbol("", {
      on_list = function(args)
        local ok = LineWriter(fd)(resolver(args.items))
        if ok then return guarded_callback(callback, dest_fpath, fzf_opts) end
      end,
    })
  end
end

return M
