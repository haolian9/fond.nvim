local M = {}

local api = vim.api
local jelly = require("infra.jellyfish")("fond")
local fs = require("infra.fs")
local state = require("fond.state")
local project = require("infra.project")
local fn = require("infra.fn")
local ex = require("infra.ex")

local function make_handler(srcname, choice_interpreter)
  -- stylua: ignore
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

M.files = make_handler("files")
M.git_files = make_handler("git_files")
M.git_modified_files = make_handler("git_modified_files")
M.mru = make_handler("mru")

M.siblings = make_handler("siblings", function(choices)
  return fs.joinpath(vim.fn.expand("%:p:h"), choices[1])
end)

M.buffers = make_handler("buffers", function(choices)
  local fname = choices[1]
  if vim.startswith(fname, "/") then return fname end
  return fs.joinpath(project.working_root(), fname)
end)

M.lsp_symbols = (function()
  local function choice_interpreter(choices)
    local choice = choices[1]

    local row_end = string.find(choice, ",", 1, true)
    if row_end == nil then return end
    local row = string.sub(choice, 1, row_end - 1)

    local col_end = string.find(choice, " ", row_end + 2, true)
    if col_end == nil then return end
    local col = string.sub(choice, row_end + 1, col_end - 1)

    return tonumber(col) - 1, tonumber(row)
  end

  return function(query, action, choices)
    state.queries["lsp_symbols"] = query
    local col, row = choice_interpreter(choices)
    local win_open_cmd

    if action == "ctrl-/" then
      win_open_cmd = "vsplit"
    elseif action == "ctrl-o" then
      win_open_cmd = "split"
    elseif action == "ctrl-m" then
      win_open_cmd = nil
    else
      win_open_cmd = nil
    end

    if win_open_cmd ~= nil then ex(win_open_cmd) end
    local win_id = api.nvim_get_current_win()
    api.nvim_win_set_cursor(win_id, { row, col })
  end
end)()

M.windows = (function()
  local function choice_interpreter(choices)
    local choice = choices[1]
    local plain = string.sub(choice, 1, string.find(choice, " ", 1, true) - 1)
    local parts = fn.split(plain, ",", 1)
    -- win_id, bufnr
    return tonumber(parts[1]), tonumber(parts[2])
  end

  return function(query, action, choices)
    state.queries["windows"] = query
    local src_win_id, src_bufnr = choice_interpreter(choices)
    local win_open_cmd

    if action == "ctrl-/" then
      win_open_cmd = "vsplit"
    elseif action == "ctrl-o" then
      win_open_cmd = "split"
    elseif action == "ctrl-m" then
      win_open_cmd = nil
    else
      win_open_cmd = nil
    end

    local src_view
    local src_wo = {}
    api.nvim_win_call(src_win_id, function()
      src_view = vim.fn.winsaveview()
      -- todo: window-local options
      for _, opt in ipairs({ "list" }) do
        src_wo[opt] = api.nvim_win_get_option(src_win_id, opt)
      end
    end)
    if win_open_cmd ~= nil then ex(win_open_cmd) end
    local win_id = api.nvim_get_current_win()
    api.nvim_win_call(win_id, function()
      -- it's unnecessary to wrap this line inside win_call, but i like to narrow scope
      api.nvim_win_set_buf(win_id, src_bufnr)
      vim.fn.winrestview(src_view)
      for opt, val in pairs(src_wo) do
        api.nvim_win_set_option(win_id, opt, val)
      end
    end)
  end
end)()

return M
