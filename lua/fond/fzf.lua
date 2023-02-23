local api = vim.api
local uv = vim.loop

local jelly = require("infra.jellyfish")("fond")
local state = require("fond.state")
local bufrename = require("infra.bufrename")
local fn = require("infra.fn")
local ex = require("infra.ex")

local function resolve_dimensions()
  -- show prompt at cursor line when possible
  -- horizental center

  local win_id = api.nvim_get_current_win()

  local winfo = assert(vim.fn.getwininfo(win_id)[1])
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

local function main(src_fpath, last_query, callback, opts)
  assert(callback ~= nil)
  opts = vim.tbl_extend("keep", opts or {}, {
    pending_unlink = false,
    -- honor those options
    source_length = nil,
    source_max_width = nil,
    -- same to fzf --with-nth
    with_nth = nil,
  })

  -- setup buf
  local bufnr
  do
    bufnr = api.nvim_create_buf(false, true)
    api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  end

  -- setup win
  local win_id
  do
    local width, height, row, col = resolve_dimensions()
    -- stylua: ignore
    win_id = api.nvim_open_win(bufnr, true, {
      style = "minimal", border = "single", zindex = 250,
      relative = "win", width = width, height = height, row = row, col = col,
    })
    api.nvim_win_set_hl_ns(win_id, assert(state.ns))
  end

  local output_fpath = os.tmpname()

  -- stylua: ignore
  local cmd = {
    "fzf",
    "--ansi",
    "--input-file", src_fpath,
    "--print-query",
    "--color", "light,fg:238,bg:15,fg+:8,bg+:15,hl:9,hl+:9,query:8:regular",
    "--expect", "ctrl-/,ctrl-m,ctrl-o,ctrl-t",
    "--bind", "char:unbind(char)+clear-query+put,ctrl-/:accept,ctrl-o:accept,ctrl-t:accept",
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
      api.nvim_win_close(win_id, true)
      local cb_ok, cb_err = xpcall(function()
        -- 0: ok, 1: no match, 2: error, 130: interrupt
        if not (exit_code == 0 or exit_code == 1 or exit_code == 130) then
          jelly.err("fzf exited abnormally, code=%d, src=%s, cmd=%s", exit_code, src_fpath, vim.json.encode(cmd))
          return
        end

        local lines = fn.split(readall(output_fpath), "\n")
        local query
        local action
        local choices = {}
        do
          local parse_ok, parse_err = xpcall(function()
            if lines[1] == nil then return end
            query = lines[1]
            if lines[2] == nil then return end
            action = lines[2]
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
      -- todo what if no file is created?
      uv.fs_unlink(output_fpath)
      if opts.pending_unlink then uv.fs_unlink(src_fpath) end
      if not cb_ok then jelly.err(cb_err) end
    end,
    pty = true,
    stderr_buffered = false,
    stdout_buffered = false,
    stdin = "pipe",
  })

  bufrename(bufnr, string.format("fzf://%d", job_id))
  ex("startinsert")
end

return main
