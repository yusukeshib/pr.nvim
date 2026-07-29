local state = require("pr.state")
local util = require("pr.util")

local M = {}
local namespace = vim.api.nvim_create_namespace("pr.nvim-threads")

local function value(item)
  if item == vim.NIL then
    return nil
  end
  return item
end

local function body_lines(body)
  local lines = vim.split(tostring(body or ""), "\n", { plain = true })
  local result = {}
  for _, line in ipairs(lines) do
    if line ~= "" then
      table.insert(result, line)
    end
  end
  return #result > 0 and result or { "" }
end

function M.setup_highlights()
  vim.api.nvim_set_hl(0, "PRThread", { default = true, link = "DiagnosticInfo" })
  vim.api.nvim_set_hl(0, "PRResolved", { default = true, link = "DiagnosticOk" })
  vim.api.nvim_set_hl(0, "PRAuthor", { default = true, link = "Title" })
  vim.api.nvim_set_hl(0, "PRBody", { default = true, link = "Comment" })
end

function M.index(threads)
  local session = state.get()
  if not session then
    return
  end
  session.threads = threads or {}
  session.threads_by_path = {}
  for _, thread in ipairs(session.threads) do
    local path = value(thread.path)
    local line = tonumber(value(thread.line) or value(thread.originalLine))
    if path and line and value(thread.diffSide) == "RIGHT" and not value(thread.isOutdated) then
      session.threads_by_path[path] = session.threads_by_path[path] or {}
      session.threads_by_path[path][line] = session.threads_by_path[path][line] or {}
      table.insert(session.threads_by_path[path][line], thread)
    end
  end
end

local function virtual_lines(threads)
  local lines = {}
  for _, thread in ipairs(threads) do
    local resolved = value(thread.isResolved) == true
    local status = resolved and "resolved" or "open"
    local comments = thread.comments and thread.comments.nodes or {}
    for index, comment in ipairs(comments) do
      local author = comment.author and value(comment.author.login) or "ghost"
      local prefix = index == 1 and ("  ● %s · %s "):format(author, status) or ("  ↳ %s "):format(author)
      table.insert(lines, { { prefix, resolved and "PRResolved" or "PRAuthor" } })
      for _, text in ipairs(body_lines(value(comment.body))) do
        table.insert(lines, { { "    " .. text, "PRBody" } })
      end
    end
  end
  return lines
end

function M.apply(buf)
  local session = state.get()
  if not session or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  local name = vim.api.nvim_buf_get_name(buf)
  local relative = util.relative(name, session.workspace)
  local by_line = relative and session.threads_by_path and session.threads_by_path[relative]
  if not by_line then
    return
  end

  local count = vim.api.nvim_buf_line_count(buf)
  for line, threads in pairs(by_line) do
    if line >= 1 and line <= count then
      pcall(vim.api.nvim_buf_set_extmark, buf, namespace, line - 1, 0, {
        virt_lines = virtual_lines(threads),
        virt_lines_above = false,
        sign_text = "●",
        sign_hl_group = value(threads[1].isResolved) and "PRResolved" or "PRThread",
        priority = 80,
      })
    end
  end
end

function M.apply_loaded()
  local session = state.get()
  if not session then
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if name ~= "" and util.is_within(name, session.workspace) then
      M.apply(buf)
    end
  end
end

function M.at_cursor()
  local session = state.get()
  if not session then
    return {}
  end
  local relative = util.relative(vim.api.nvim_buf_get_name(0), session.workspace)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  return relative
      and session.threads_by_path
      and session.threads_by_path[relative]
      and session.threads_by_path[relative][line]
    or {}
end

function M.select(callback)
  local threads = M.at_cursor()
  if #threads == 0 then
    util.notify("no review thread on this line", vim.log.levels.WARN)
    return
  end
  if #threads == 1 then
    callback(threads[1])
    return
  end
  vim.ui.select(threads, {
    prompt = "Select review thread",
    format_item = function(thread)
      local first = thread.comments and thread.comments.nodes and thread.comments.nodes[1]
      return first and ((first.author and first.author.login or "ghost") .. ": " .. (first.body or "")) or thread.id
    end,
  }, function(thread)
    if thread then
      callback(thread)
    end
  end)
end

function M.jump(direction)
  local session = state.get()
  if not session then
    return
  end
  local relative = util.relative(vim.api.nvim_buf_get_name(0), session.workspace)
  local by_line = relative and session.threads_by_path and session.threads_by_path[relative]
  if not by_line then
    util.notify("no review threads in this file")
    return
  end
  local lines = vim.tbl_keys(by_line)
  table.sort(lines)
  local current = vim.api.nvim_win_get_cursor(0)[1]
  local target
  if direction > 0 then
    for _, line in ipairs(lines) do
      if line > current then
        target = line
        break
      end
    end
    target = target or lines[1]
  else
    for index = #lines, 1, -1 do
      if lines[index] < current then
        target = lines[index]
        break
      end
    end
    target = target or lines[#lines]
  end
  if target then
    vim.api.nvim_win_set_cursor(0, { target, 0 })
  end
end

return M
