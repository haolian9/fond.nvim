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

local function make_general_handler(srcname, choice_interpreter)
  if choice_interpreter == nil then
    -- only the first choice will be accepted
    choice_interpreter = function(choices) return choices[1] end
  end
  return function(query, action, choices)
    state.queries[srcname] = query
    local choice = choice_interpreter(choices)
    if action == "ctrl-/" then
      ex("vsplit", choice)
    elseif action == "ctrl-o" then
      ex("split", choice)
    elseif action == "ctrl-m" then
      ex("edit", choice)
    elseif action == "ctrl-t" then
      ex("tabedit", choice)
    else
      jelly.warn("no handler for action=%s", action)
    end
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
    if action == "ctrl-m" then return end
  end

  function M.windows(query, action, choices)
    state.queries["windows"] = query
    local src_win_id, src_bufnr = choice_interpreter(choices)
    local win_open_cmd = action_interpreter(action)

    local src_view
    local src_wo = {}
    api.nvim_win_call(src_win_id, function()
      src_view = vim.fn.winsaveview()
      for _, opt in ipairs({ "list" }) do
        src_wo[opt] = prefer.wo(src_win_id, opt)
      end
      -- no considering window-local options
    end)
    if win_open_cmd ~= nil then ex(win_open_cmd) end
    local winid = api.nvim_get_current_win()
    api.nvim_win_call(winid, function()
      -- it's unnecessary to wrap this line inside win_call, but i like to narrow scope
      api.nvim_win_set_buf(winid, src_bufnr)
      vim.fn.winrestview(src_view)
      for opt, val in pairs(src_wo) do
        prefer.wo(winid, opt, val)
      end
    end)
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

  local function action_interpreter(action)
    if action == "ctrl-/" then return "vsplit" end
    if action == "ctrl-o" then return "split" end
    if action == "ctrl-m" then return end
  end

  function M.lsp_document_symbols(query, action, choices)
    state.queries["lsp_document_symbols"] = query
    local _, col, row = choice_interpreter(choices)
    local win_open_cmd = action_interpreter(action)

    jumplist.push_here()

    if win_open_cmd ~= nil then ex(win_open_cmd) end
    local winid = api.nvim_get_current_win()
    api.nvim_win_set_cursor(winid, { row, col })
  end

  function M.lsp_workspace_symbols(query, action, choices)
    state.queries["lsp_workspace_symbols"] = query
    local fpath, col, row = choice_interpreter(choices)
    local win_open_cmd = action_interpreter(action)

    jumplist.push_here()

    if win_open_cmd ~= nil then ex(win_open_cmd) end
    local winid = api.nvim_get_current_win()
    ex("edit", fpath)
    api.nvim_win_set_cursor(winid, { row, col })
  end
end

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

  if action == "ctrl-/" then
    ex("vsplit", path)
  elseif action == "ctrl-o" then
    ex("split", path)
  elseif action == "ctrl-m" then
    ex("edit", path)
  elseif action == "ctrl-t" then
    ex("tabedit", path)
  else
    jelly.warn("no handler for action=%s", action)
    return
  end

  jelly.debug("path=%s, line=%d, col=%d", path, lnum, col)
  api.nvim_win_set_cursor(0, { lnum + 1, col })
end

return M
