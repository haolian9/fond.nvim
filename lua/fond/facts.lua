local M = {}

local coreutils = require("infra.coreutils")
local highlighter = require("infra.highlighter")
local ni = require("infra.ni")

do
  local root = string.format("/tmp/%s-nvim-fzf", coreutils.whoami())
  assert(coreutils.mkdir(root, tonumber("700", 8)))
  --stores all tempfiles
  M.root = root
end

do
  local ns = ni.create_namespace("fzf.floatwin")
  local hi = highlighter(ns)
  if vim.go.background == "light" then
    hi("NormalFloat", { fg = 8 })
    hi("WinSeparator", { fg = 243 })
  else
    hi("NormalFloat", { fg = 7 })
    hi("WinSeparator", { fg = 243 })
  end
  M.floatwin_ns = ns
end

return M
