local config = require("pr.config")

local M = {}

local function merge_ranges(ranges)
  table.sort(ranges, function(a, b)
    return a[1] < b[1]
  end)
  local merged = {}
  for _, range in ipairs(ranges) do
    local previous = merged[#merged]
    if previous and range[1] <= previous[2] + 1 then
      previous[2] = math.max(previous[2], range[2])
    else
      table.insert(merged, { range[1], range[2] })
    end
  end
  return merged
end

function M.build(line_count, hunks, context, min_lines)
  if line_count < 1 or not hunks or #hunks == 0 then
    return {}
  end
  context = context or 3
  min_lines = min_lines or 2

  local visible = {}
  for _, hunk in ipairs(hunks) do
    local added = hunk.added or {}
    local start = math.max(1, tonumber(added.start) or 1)
    local count = math.max(1, tonumber(added.count) or 0)
    table.insert(visible, {
      math.max(1, start - context),
      math.min(line_count, start + count - 1 + context),
    })
  end
  visible = merge_ranges(visible)

  local folds = {}
  local cursor = 1
  local function add(first, last)
    if last >= first and last - first + 1 >= min_lines then
      table.insert(folds, { first, last })
    end
  end
  for _, range in ipairs(visible) do
    add(cursor, range[1] - 1)
    cursor = math.max(cursor, range[2] + 1)
  end
  add(cursor, line_count)
  return folds
end

local function apply_to_window(win, buf, ranges)
  if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
    return
  end
  vim.api.nvim_win_call(win, function()
    local view = vim.fn.winsaveview()
    vim.wo.foldmethod = "manual"
    vim.wo.foldenable = true
    vim.wo.foldlevel = 0
    vim.wo.foldtext = "v:lua.require'pr.folds'.text()"
    vim.cmd("silent! normal! zE")
    for _, range in ipairs(ranges) do
      vim.cmd(("silent! %d,%dfold"):format(range[1], range[2]))
    end
    vim.fn.winrestview(view)
  end)
end

function M.refresh(buf)
  if not config.options.folds.enabled or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local ok, gitsigns = pcall(require, "gitsigns")
  if not ok then
    return
  end
  local hunks = gitsigns.get_hunks(buf)
  if hunks == nil then
    return
  end
  local ranges =
    M.build(vim.api.nvim_buf_line_count(buf), hunks, config.options.folds.context, config.options.folds.min_lines)
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    apply_to_window(win, buf, ranges)
  end
end

function M.text()
  local count = vim.v.foldend - vim.v.foldstart + 1
  return ("  ··· %d unchanged line%s ···"):format(count, count == 1 and "" or "s")
end

return M
