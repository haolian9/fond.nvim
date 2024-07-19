local augroups = require("infra.augroups")
local Ephemeral = require("infra.Ephemeral")
local ex = require("infra.ex")
local feedkeys = require("infra.feedkeys")
local jelly = require("infra.jellyfish")("fond.handlers.helps", "debug")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local unsafe = require("infra.unsafe")

local Act = require("fond.handlers.Act")
local state = require("fond.state")

local help
do
  local function has_help_win()
    local tabid = ni.get_current_tabpage()
    local winids = ni.tabpage_list_wins(tabid)
    --the help win trends to be at the bottom
    for i = #winids, 1, -1 do
      local bufnr = ni.win_get_buf(winids[i])
      if prefer.bo(bufnr, "buftype") == "help" then return true end
    end
    return false
  end

  local function open_in_tab(subject) ex.eval("tab help %s", subject) end

  local openmode_to_wincmd = { left = "L", right = "H", above = "K", below = "J" }

  ---@param subject string
  ---@param open_mode infra.bufopen.Mode
  function help(open_mode, subject)
    if has_help_win() then
      if open_mode == "tab" then
        return open_in_tab(subject)
      else
        return ex("help", subject)
      end
    end

    local bufnr = Ephemeral({ namepat = "helphelp://{bufnr}", modifiable = false })
    unsafe.prepare_help_buffer(bufnr)

    local winid = ni.open_win(bufnr, false, { relative = "editor", row = 0, col = 0, width = 1, height = 1, hide = true })

    local aug = augroups.BufAugroup(bufnr, "helphelp", false)
    aug:once("BufWipeout", {
      callback = function()
        vim.schedule(function() --to avoid E1159: cannot split a window when closing the buffer
          assert(ni.win_is_valid(winid))
          if open_mode == "inplace" then
            local help_bufnr = ni.win_get_buf(winid)
            ex("wincmd", "p")
            ni.win_set_buf(0, help_bufnr)
            ni.win_close(winid, false)
          elseif open_mode == "tab" then
            open_in_tab(subject)
            ni.win_close(winid, false)
          else
            ex.cmd("wincmd", assert(openmode_to_wincmd[open_mode]))
            feedkeys("zt" .. "0" .. "g$", "n")
          end
        end)
        aug:unlink()
      end,
    })

    ex("help", subject)
  end
end

local act
do
  local function normalize_choice(choice) return choice end

  local single = {
    ["ctrl-m"] = function(subject) help("inplace", subject) end,
    ["ctrl-/"] = function(subject) help("right", subject) end,
    ["ctrl-o"] = function(subject) help("below", subject) end,
    ["ctrl-t"] = function(subject) help("tab", subject) end,
  }

  local batch = {}

  act = Act("helps", normalize_choice, single, batch)
end

---@type fond.fzf.Handler
return function(query, action, choices)
  state.queries.helps = query

  act(action, choices)
end
