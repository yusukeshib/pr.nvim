if vim.g.loaded_pr_nvim == 1 then
  return
end
vim.g.loaded_pr_nvim = 1

local review = require("pr")
review.setup()

vim.api.nvim_create_user_command("PROpen", function(command)
  review.open(command.args)
end, {
  nargs = "+",
  desc = "Open a read-only GitHub pull request review",
})

vim.api.nvim_create_user_command("PRClose", function()
  review.close()
end, {
  desc = "Close the active GitHub pull request review",
})

vim.api.nvim_create_user_command("PRRefresh", function()
  review.refresh()
end, {
  desc = "Refresh GitHub pull request review threads",
})

vim.api.nvim_create_user_command("PRFiles", function()
  review.files()
end, {
  desc = "List pull request changed files",
})
