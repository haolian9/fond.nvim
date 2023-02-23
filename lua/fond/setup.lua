local api = vim.api

local coreutils = require("infra.coreutils")
local state = require("fond.state")

local has_ran = false

return function()
  assert(not has_ran)

  do
    local root = string.format("/tmp/%s-nvim-fzf", coreutils.whoami())
    assert(coreutils.mkdir(root, tonumber("700", 8)))
    state.root = root
  end

  do
    state.ns = api.nvim_create_namespace("fzf.floatwin")
    api.nvim_set_hl(state.ns, "VertSplit", { ctermfg = 8 })
    api.nvim_set_hl(state.ns, "NormalFloat", { ctermfg = 8 })
  end

  has_ran = true
end
