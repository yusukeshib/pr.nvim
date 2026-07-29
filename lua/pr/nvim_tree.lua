local state = require("pr.state")
local util = require("pr.util")

local M = {}

function M.filter(path)
  local session = state.get()
  if not session or not session.workspace or not session.changed_set then
    return false
  end
  if not util.is_within(path, session.workspace) then
    return false
  end

  local relative = util.relative(path, session.workspace)
  if not relative or relative == "" then
    return false
  end
  if session.changed_set[relative] then
    return false
  end

  local prefix = relative .. "/"
  for changed_path in pairs(session.changed_set) do
    if changed_path:sub(1, #prefix) == prefix then
      return false
    end
  end
  return true
end

function M.open(workspace, changed_files)
  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then
    util.notify("nvim-tree is not installed; use normal file navigation", vim.log.levels.WARN)
    return
  end
  local source_win = vim.api.nvim_get_current_win()
  api.tree.open({ path = workspace })
  for _, entry in ipairs(changed_files or {}) do
    local path = vim.fs.joinpath(workspace, entry.path)
    if entry.status ~= "D" and vim.uv.fs_stat(path) then
      api.tree.find_file({ buf = path, focus = false })
    end
  end
  if vim.api.nvim_win_is_valid(source_win) then
    vim.api.nvim_set_current_win(source_win)
  end
end

function M.restore(path)
  local ok, api = pcall(require, "nvim-tree.api")
  if ok and path and path ~= "" then
    pcall(api.tree.change_root, path)
    pcall(api.tree.reload)
  end
end

function M.reload()
  local ok, api = pcall(require, "nvim-tree.api")
  if ok then
    pcall(api.tree.reload)
  end
end

return M
