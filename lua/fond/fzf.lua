local bufrename = require("infra.bufrename")
local dictlib = require("infra.dictlib")
local ex = require("infra.ex")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("fzf")
local listlib = require("infra.listlib")
local prefer = require("infra.prefer")
local rifts = require("infra.rifts")

local api = vim.api
local uv = vim.loop

local mandatory_args = {}
do
  local colors --ref: https://man.archlinux.org/man/fzf.1.en#color=
  if vim.go.background == "light" then
    colors = "light,fg:238,bg:15,fg+:8,bg+:15,hl:9,hl+:9,query:8:regular"
  else
    colors = "dark,fg:7,bg:0,fg+:15,bg+:0,hl:9,hl+:9,query:7:regular"
  end

  -- stylua: ignore
  listlib.extend(mandatory_args, {
    "--ansi",
    "--print-query",
    "--bind", "char:unbind(char)+clear-query+put", -- placeholder&clear
    "--bind", "ctrl-/:accept,ctrl-o:accept,ctrl-t:accept,space:accept", -- keys to accept
    "--expect", "ctrl-/,ctrl-m,ctrl-o,ctrl-t,space",
    "--color", colors,
  })
end

--show prompt at cursor line when possible horizental center
local function resolve_geometry()
  local winid = api.nvim_get_current_win()

  local winfo = assert(vim.fn.getwininfo(winid)[1])
  local win_width, win_height = winfo.width, winfo.height
  -- takes folding into account
  local win_row = vim.fn.winline()

  --below magic numbers are based on
  --* urxvt, width=136, height=30
  --* st, width=174, height=39

  local width, col
  if win_width > 70 then
    width = math.floor(win_width * 0.6)
    col = math.floor(win_width * 0.2)
  elseif win_width > 45 then
    width = math.floor(win_width * 0.75)
    col = math.floor(win_width * 0.125)
  else
    width = win_width - 2 -- borders
    col = 0
  end

  local height, row
  if win_height > 15 then
    height = math.floor(win_height * 0.45)
    row = math.max(win_row - height - 1, 0)
  else
    height = win_height - 2 -- borders
    row = 0
  end

  return { width = width, height = height, row = row, col = col }
end

---@param path string @absolute path of outputfile produced by fzf
---@return string?,string?,string[]? @query,action,choices
local function parse_output_file(path)
  --drain the io.lines to free the fd
  local iter = fn.iter(fn.tolist(io.lines(path)))

  local query = iter()
  if query == nil then return end

  local action = iter()
  if action == nil then return end
  -- treat <space> as <c-m>
  if action == "space" then action = "ctrl-m" end

  local choices = {}
  for line in iter do
    if #line == 0 then break end
    table.insert(choices, line)
  end
  if #choices == 0 then return end

  return query, action, choices
end

---@class fond.fzf.Opts
---@field pending_unlink?   boolean
---@field source_length?    number
---@field source_max_width? number
---@field with_nth?         number @'fzf --with-nth'
---@field prompt?           string @'fzf --prompt'

---@alias fond.fzf.Handler fun(query: string, action: string, choices: string[])

---@param opts fond.fzf.Opts
local function fulfill_opts(opts) opts.pending_unlink = fn.nilor(opts.pending_unlink, false) end

---@param src_fpath string
---@param last_query? string
---@param handler fond.fzf.Handler
---@param opts fond.fzf.Opts
return function(src_fpath, last_query, handler, opts)
  assert(handler ~= nil)
  fulfill_opts(opts)

  local bufnr
  do
    bufnr = api.nvim_create_buf(false, true) --no ephemeral here
    prefer.bo(bufnr, "bufhidden", "wipe")
  end

  local winid
  do
    local winopts = dictlib.merged({ relative = "win", border = "single", zindex = 250 }, resolve_geometry())
    winid = rifts.open.win(bufnr, true, winopts)
    api.nvim_win_set_hl_ns(winid, rifts.ns)
  end

  local output_fpath = os.tmpname()

  local cmd = { "fzf" }
  do
    listlib.extend(cmd, mandatory_args)
    listlib.extend(cmd, { "--input-file", src_fpath, "--output-file", output_fpath })
    if last_query ~= nil then
      table.insert(cmd, "--query")
      table.insert(cmd, last_query)
    end
    if opts.with_nth ~= nil then
      table.insert(cmd, "--with-nth")
      table.insert(cmd, opts.with_nth)
    end
    if opts.prompt ~= nil then
      table.insert(cmd, "--prompt")
      table.insert(cmd, opts.prompt)
    end
  end

  local job_id = vim.fn.termopen(cmd, {
    on_exit = function(_, exit_code)
      api.nvim_win_close(winid, false)

      if not (exit_code == 0 or exit_code == 1 or exit_code == 130) then
        -- 0: ok, 1: no match, 2: error, 130: interrupt
        return jelly.err("fzf exited abnormally, code=%d, src=%s, cmd=%s", exit_code, src_fpath, vim.json.encode(cmd))
      end

      local query, action, choices = parse_output_file(output_fpath)
      if not (query and action and choices) then return end

      local cb_ok, cb_err = xpcall(handler, debug.traceback, query, action, choices)
      uv.fs_unlink(output_fpath)
      if opts.pending_unlink then uv.fs_unlink(src_fpath) end
      if not cb_ok then jelly.err("fzf callback error: %s", cb_err) end
    end,
    pty = true,
    stderr_buffered = false,
    stdout_buffered = false,
    stdin = "pipe",
  })

  bufrename(bufnr, string.format("fzf://%d", job_id))
  ex("startinsert")
end
