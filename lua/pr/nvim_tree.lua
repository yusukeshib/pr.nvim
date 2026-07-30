local util = require("pr.util")

local M = {}

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
