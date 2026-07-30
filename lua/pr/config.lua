local M = {}

M.defaults = {
  state_dir = vim.fn.stdpath("state") .. "/pr.nvim",
  readonly = true,
  gitsigns = {
    linehl = true,
    show_deleted = true,
    word_diff = true,
  },
  folds = {
    enabled = true,
    context = 3,
    min_lines = 2,
  },
  keymaps = {
    files = "<leader>pf",
    comment = "gc",
    reply = "gr",
    resolve = "gR",
    next_thread = "]t",
    previous_thread = "[t",
    refresh = "R",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

return M
