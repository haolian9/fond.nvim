local M = {}

local ex = require("infra.ex")
local fn = require("infra.fn")
local fs = require("infra.fs")
local jelly = require("infra.jellyfish")("fzf.handlers")
local jumplist = require("infra.jumplist")
local prefer = require("infra.prefer")
local project = require("infra.project")
local strlib = require("infra.strlib")

local state = require("fond.state")

local api = vim.api

local default_interpreters = {}
do
  ---@param action string
  ---@return string?
  function default_interpreters.action(action)
    if action == "ctrl-/" then return "vsplit" end
    if action == "ctrl-o" then return "split" end
    if action == "ctrl-m" then return "edit" end
    if action == "ctrl-t" then return "tabedit" end
    jelly.warn("no handler for action=%s", action)
  end

  --only the first choice will be accepted
  ---@param choices string[]
  function default_interpreters.choice(choices) return choices[1] end
end

---@return fond.fzf.Handler
local function make_general_handler(src_name, choice_interpreter, action_interpreter)
  if choice_interpreter == nil then choice_interpreter = default_interpreters.choice end
  if action_interpreter == nil then action_interpreter = default_interpreters.action end
  return function(query, action, choices)
    state.queries[src_name] = query
    local choice = choice_interpreter(choices)
    local split = action_interpreter(action)
    if split == nil then return end
    ex(split, choice)
  end
end

M.files = make_general_handler("files")
M.git_files = make_general_handler("git_files")
M.git_modified_files = make_general_handler("git_modified_files")
M.git_status_files = make_general_handler("git_status_files", function(choices)
  local line = choices[1]
  --it should start with a 3-length prefix: `?? ` or ` M ` or ` D ` ...
  assert(string.sub(line, 3, 3) == " ")
  return string.sub(line, 4)
end)
M.siblings = make_general_handler("siblings", function(choices) return fs.joinpath(vim.fn.expand("%:p:h"), choices[1]) end)
M.buffers = make_general_handler("buffers", function(choices)
  local fname = choices[1]
  if strlib.startswith(fname, "/") then return fname end
  return fs.joinpath(project.working_root(), fname)
end)

do
  local function choice_interpreter(choices)
    local choice = choices[1]
    local plain = string.sub(choice, 1, strlib.find(choice, " ") - 1)
    local parts = fn.split(plain, ",", 1)
    -- winid, bufnr
    return tonumber(parts[1]), tonumber(parts[2])
  end

  local function action_interpreter(action)
    if action == "ctrl-/" then return "vsplit" end
    if action == "ctrl-o" then return "split" end
    if action == "ctrl-m" then return "vsplit" end
    if action == "ctrl-t" then return jelly.warn("unreasonable action for fond.windows: <c-t>") end
    jelly.warn("unexpected action for fond.windows: %s", action)
  end

  ---@type fond.fzf.Handler
  function M.windows(query, action, choices)
    state.queries["windows"] = query
    local src_win_id, src_bufnr = choice_interpreter(choices)
    local win_open_cmd = action_interpreter(action)
    if win_open_cmd == nil then return end

    local src_view
    local src_wo = {}
    api.nvim_win_call(src_win_id, function() src_view = vim.fn.winsaveview() end)
    for _, opt in ipairs({ "list" }) do
      src_wo[opt] = prefer.wo(src_win_id, opt)
    end

    ex(win_open_cmd)

    local winid = api.nvim_get_current_win()
    api.nvim_win_set_buf(winid, src_bufnr)
    vim.fn.winrestview(src_view)
    for opt, val in pairs(src_wo) do
      prefer.wo(winid, opt, val)
    end
  end
end

do
  local function choice_interpreter(choices)
    local choice = choices[1]

    local chunks = fn.split_iter(choice, ",")
    local fpath = chunks()
    local row = chunks()
    local col = chunks()

    return fpath, tonumber(col) - 1, tonumber(row)
  end

  ---@type fond.fzf.Handler
  function M.lsp_document_symbols(query, action, choices)
    state.queries["lsp_document_symbols"] = query
    local _, col, row = choice_interpreter(choices)
    local win_open_cmd = default_interpreters.action(action)
    if win_open_cmd == nil then return end

    jumplist.push_here()

    ex(win_open_cmd, "%")
    api.nvim_win_set_cursor(0, { row, col })
  end

  ---@type fond.fzf.Handler
  function M.lsp_workspace_symbols(query, action, choices)
    state.queries["lsp_workspace_symbols"] = query
    local fpath, col, row = choice_interpreter(choices)
    local win_open_cmd = default_interpreters.action(action)
    if win_open_cmd == nil then return end

    jumplist.push_here()

    ex(win_open_cmd, fpath)
    api.nvim_win_set_cursor(0, { row, col })
  end
end

---@type fond.fzf.Handler
function M.olds(query, action, choices)
  state.queries["olds"] = query

  local path, lnum, col
  do
    local line = choices[1]
    path, lnum, col = string.match(line, "^(.+):(%d+):(%d+)$")
    lnum = tonumber(lnum)
    col = tonumber(col)
    assert(path and lnum and col)
  end

  local win_open_cmd = default_interpreters.action(action)
  if win_open_cmd == nil then return end

  ex(win_open_cmd, path)

  do --goto that position
    jelly.debug("path=%s, line=%d, col=%d", path, lnum, col)
    local winid = api.nvim_get_current_win()
    local row_max = api.nvim_buf_line_count(api.nvim_win_get_buf(winid))
    local row = lnum + 1
    if row <= row_max then
      api.nvim_win_set_cursor(winid, { row, col })
    else
      jelly.warn("goto last line, as #%d line no longer exists", lnum)
      api.nvim_win_set_cursor(winid, { row_max, col })
    end
  end
end

---@type fond.fzf.Handler
function M.ctags_file(query, action, choices)
  state.queries["ctags_file"] = query

  jelly.info("query='%s', action='%s', choices='%s'", query, action, choices)

  local col
  do
    local line = choices[1]
    col = string.match(line, ":(%d+)$")
    col = tonumber(col)
    assert(col)
  end

  local win_open_cmd = default_interpreters.action(action)
  if win_open_cmd == nil then return end

  jumplist.push_here()

  ex(win_open_cmd, "%")
  api.nvim_win_set_cursor(0, { col, 0 })
end

return M
