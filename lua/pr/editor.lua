local util = require("pr.util")

local M = {}

local function close(win, buf)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  elseif buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

function M.open(opts)
  opts = opts or {}
  local width = math.max(50, math.floor(vim.o.columns * 0.65))
  local height = math.max(8, math.floor(vim.o.lines * 0.3))
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines or { "" })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = " " .. (opts.title or "GitHub Review") .. " ",
    title_pos = "center",
    width = width,
    height = height,
    row = row,
    col = col,
  })
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  local function submit()
    local body = util.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
    if body == "" then
      util.notify("comment cannot be empty", vim.log.levels.WARN)
      return
    end
    close(win, buf)
    opts.on_submit(body)
  end

  vim.keymap.set({ "n", "i" }, "<C-s>", submit, { buffer = buf, desc = "Submit GitHub review comment" })
  vim.keymap.set("n", "q", function()
    close(win, buf)
  end, { buffer = buf, desc = "Cancel" })
  vim.keymap.set("n", "<Esc>", function()
    close(win, buf)
  end, { buffer = buf, desc = "Cancel" })
  vim.cmd.startinsert()
end

return M
