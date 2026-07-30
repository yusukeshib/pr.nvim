local state = require("pr.state")
local util = require("pr.util")

local M = {}

local status_highlights = {
  A = "GitSignsAdd",
  D = "GitSignsDelete",
  M = "GitSignsChange",
  R = "GitSignsChange",
}

function M.entries(session)
  local counts = {}
  for _, thread in ipairs(session.threads or {}) do
    local path = thread.path == vim.NIL and nil or thread.path
    if path then
      local count = counts[path] or { total = 0, unresolved = 0 }
      count.total = count.total + 1
      if thread.isResolved ~= true then
        count.unresolved = count.unresolved + 1
      end
      counts[path] = count
    end
  end

  local entries = {}
  for _, file in ipairs(session.changed_files or {}) do
    local count = counts[file.path] or { total = 0, unresolved = 0 }
    table.insert(entries, {
      path = file.path,
      status = file.status,
      old_path = file.old_path,
      thread_count = count.total,
      unresolved_count = count.unresolved,
    })
  end
  return entries
end

function M.comment_badge(entry)
  if entry.unresolved_count > 0 then
    return ("●%d"):format(entry.unresolved_count)
  end
  if entry.thread_count > 0 then
    return ("✓%d"):format(entry.thread_count)
  end
  return ""
end

local function open_file(session, entry)
  if entry.status == "D" then
    util.notify("deleted-file review is not implemented yet", vim.log.levels.WARN)
    return
  end
  local path = vim.fs.joinpath(session.workspace, entry.path)
  if not vim.uv.fs_stat(path) then
    util.notify("file does not exist in the PR workspace: " .. entry.path, vim.log.levels.ERROR)
    return
  end
  local win = session.content_window
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

local function fallback(session, entries)
  vim.ui.select(entries, {
    prompt = "PR changed files",
    format_item = function(entry)
      return ("%s  %-4s %s"):format(entry.status, M.comment_badge(entry), entry.path)
    end,
  }, function(entry)
    if entry then
      open_file(session, entry)
    end
  end)
end

function M.open()
  local session = state.get()
  if not session then
    util.notify("no active review", vim.log.levels.WARN)
    return
  end
  local entries = M.entries(session)
  local ok = pcall(require, "telescope.pickers")
  if not ok then
    fallback(session, entries)
    return
  end

  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values
  local entry_display = require("telescope.pickers.entry_display")
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local displayer = entry_display.create({
    separator = " ",
    items = { { width = 1 }, { width = 5 }, { remaining = true } },
  })

  pickers
    .new({}, {
      prompt_title = ("PR #%d changed files"):format(session.number),
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          local absolute_path = vim.fs.joinpath(session.workspace, entry.path)
          return {
            value = entry,
            ordinal = entry.path,
            filename = vim.uv.fs_stat(absolute_path) and absolute_path or nil,
            display = function()
              local badge = M.comment_badge(entry)
              local badge_hl = entry.unresolved_count > 0 and "DiagnosticWarn" or "DiagnosticOk"
              return displayer({
                { entry.status, status_highlights[entry.status] or "Normal" },
                { badge, badge_hl },
                entry.path,
              })
            end,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = conf.file_previewer({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            open_file(session, selection.value)
          end
        end)
        return true
      end,
    })
    :find()
end

return M
