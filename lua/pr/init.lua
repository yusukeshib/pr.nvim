local config = require("pr.config")
local files = require("pr.files")
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

function M.files()
  files.open()
end

return M
