local config = require("pr.config")
local nvim_tree = require("pr.nvim_tree")
local session = require("pr.session")
local threads = require("pr.threads")

local M = {}

function M.setup(opts)
  local options = config.setup(opts)
  threads.setup_highlights()
  return options
end

function M.open(target)
  session.open(target)
end

function M.close()
  session.close()
end

function M.refresh()
  session.refresh()
end

function M.filter_file(path)
  return nvim_tree.filter(path)
end

return M
