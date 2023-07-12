local bufrename = require("infra.bufrename")
local ex = require("infra.ex")
local fn = require("infra.fn")
local jelly = require("infra.jellyfish")("fzf")
local prefer = require("infra.prefer")

local state = require("fond.state")

local api = vim.api
local uv = vim.loop

local function resolve_geometry()
  -- show prompt at cursor line when possible
  -- horizental center

  local winid = api.nvim_get_current_win()

  local winfo = assert(vim.fn.getwininfo(winid)[1])
  local win_width, win_height = winfo.width, winfo.height
  -- takes folding into account
  local win_row = vim.fn.winline()

  local width = math.floor(win_width * 0.75)
  local height = math.floor(win_height * 0.3)
  local row = math.max(win_row - height - 1, 0)
  local col = math.floor(win_width * 0.1)

  return width, height, row, col
end

local function readall(path)
  local file, open_err = uv.fs_open(path, "r", tonumber("600", 8))
  assert(open_err == nil, open_err)
  local ok, content = xpcall(function()
    local stat, stat_err = uv.fs_fstat(file)
    assert(stat_err == nil, stat_err)
    -- for the output of fzf, file name max 4096 in linux
    assert(stat.size < 4096 * 2)
    local content = uv.fs_read(file, stat.size)
    assert(#content == stat.size)
    return content
  end, debug.traceback)
  uv.fs_close(file)
  assert(ok, content)
  return content
end

---@class fond.fzf.Opts
---@field pending_unlink? boolean
---@field source_length? number
---@field source_max_width? number
---@field with_nth? number @same to fzf --with-nth

---@param opts fond.fzf.Opts
local function fulfill_opts(opts) opts.pending_unlink = fn.nilor(opts.pending_unlink, false) end

---@param src_fpath string
---@param last_query? string
---@param callback fun(query: string, action: string, choices: string[])
---@param opts fond.fzf.Opts
return function(src_fpath, last_query, callback, opts)
  assert(callback ~= nil)
  fulfill_opts(opts)

  -- setup buf
  local bufnr
  do
    bufnr = api.nvim_create_buf(false, true)
    prefer.bo(bufnr, "bufhidden", "wipe")
  end

  -- setup win
  local winid
  do
    local width, height, row, col = resolve_geometry()
    -- stylua: ignore
    winid = api.nvim_open_win(bufnr, true, {
      style = "minimal", border = "single", zindex = 250,
      relative = "win", width = width, height = height, row = row, col = col,
    })
    api.nvim_win_set_hl_ns(winid, assert(state.hl_ns))
  end

  local output_fpath = os.tmpname()

  -- stylua: ignore
  local cmd = {
    "fzf",
    "--ansi",
    "--input-file", src_fpath,
    "--print-query",
    "--color", "light,fg:238,bg:15,fg+:8,bg+:15,hl:9,hl+:9,query:8:regular",
    "--bind", "char:unbind(char)+clear-query+put", -- placeholder&clear
    "--bind", "ctrl-/:accept,ctrl-o:accept,ctrl-t:accept,space:accept", -- keys to accept
    "--expect", "ctrl-/,ctrl-m,ctrl-o,ctrl-t,space",
    "--output-file", output_fpath,
  }
  if last_query ~= nil then
    table.insert(cmd, "--query")
    table.insert(cmd, last_query)
  end
  if opts.with_nth ~= nil then
    table.insert(cmd, "--with-nth")
    table.insert(cmd, opts.with_nth)
  end

  local job_id = vim.fn.termopen(cmd, {
    on_exit = function(_, exit_code)
      api.nvim_win_close(winid, true)
      local cb_ok, cb_err = xpcall(function()
        if not (exit_code == 0 or exit_code == 1 or exit_code == 130) then
          -- 0: ok, 1: no match, 2: error, 130: interrupt
          return jelly.err("fzf exited abnormally, code=%d, src=%s, cmd=%s", exit_code, src_fpath, vim.json.encode(cmd))
        end

        local lines = fn.split(readall(output_fpath), "\n")
        local query
        local action
        local choices = {}
        do
          local parse_ok, parse_err = xpcall(function()
            do
              query = lines[1]
              if query == nil then return end
            end
            do
              action = lines[2]
              if action == nil then return end
              -- treat <space> as <c-m>
              if action == "space" then action = "ctrl-m" end
            end
            for i = 3, #lines do
              if #lines[i] == 0 then break end
              table.insert(choices, lines[i])
            end
          end, debug.traceback)
          if not parse_ok then return jelly.err("fzf output parse error: %s\noutput: %s", parse_err, vim.inspect(lines)) end
          if #choices == 0 then return end
        end
        local ok, err = xpcall(callback, debug.traceback, query, action, choices)
        if not ok then jelly.err(err) end
      end, debug.traceback)
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
