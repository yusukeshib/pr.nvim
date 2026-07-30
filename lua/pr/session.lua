local config = require("pr.config")
local editor = require("pr.editor")
local files = require("pr.files")
local folds = require("pr.folds")
local github = require("pr.github")
local nvim_tree = require("pr.nvim_tree")
local state = require("pr.state")
local target_parser = require("pr.target")
local threads = require("pr.threads")
local util = require("pr.util")
local workspace = require("pr.workspace")

local M = {}
local opening = false

local function with_gitsigns(session, callback)
  local ok, gitsigns = pcall(require, "gitsigns")
  if ok then
    callback(gitsigns)
  elseif not session.gitsigns_warning_shown then
    session.gitsigns_warning_shown = true
    util.notify("gitsigns.nvim is not installed", vim.log.levels.WARN)
  end
end

local function configure_gitsigns(session)
  local ok, gitsigns_config = pcall(require, "gitsigns.config")
  if not ok then
    return
  end
  session.gitsigns_previous = {
    linehl = gitsigns_config.config.linehl,
    show_deleted = gitsigns_config.config.show_deleted,
    word_diff = gitsigns_config.config.word_diff,
  }
  with_gitsigns(session, function(gitsigns)
    gitsigns.toggle_linehl(config.options.gitsigns.linehl)
    gitsigns.toggle_deleted(config.options.gitsigns.show_deleted)
    gitsigns.toggle_word_diff(config.options.gitsigns.word_diff)
  end)
end

local function restore_gitsigns(session)
  if not session.gitsigns_previous then
    return
  end
  with_gitsigns(session, function(gitsigns)
    gitsigns.toggle_linehl(session.gitsigns_previous.linehl)
    gitsigns.toggle_deleted(session.gitsigns_previous.show_deleted)
    gitsigns.toggle_word_diff(session.gitsigns_previous.word_diff)
  end)
end

local function apply_gitsigns(buf)
  local session = state.get()
  if not session or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  if not vim.b[buf].gitsigns_status_dict then
    return
  end
  session.gitsigns_base_state = session.gitsigns_base_state or {}
  local base_state = session.gitsigns_base_state[buf]
  if base_state == "pending" then
    return
  end
  if base_state == "applied" then
    folds.refresh(buf)
    return
  end

  session.gitsigns_base_state[buf] = "pending"
  with_gitsigns(session, function(gitsigns)
    vim.defer_fn(function()
      if state.get() ~= session or not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      vim.api.nvim_buf_call(buf, function()
        local ok = pcall(gitsigns.change_base, session.pr.baseRefOid, false, function(err)
          vim.schedule(function()
            if state.get() ~= session or not vim.api.nvim_buf_is_valid(buf) then
              return
            end
            if err then
              session.gitsigns_base_state[buf] = nil
              return
            end
            session.gitsigns_base_state[buf] = "applied"
            folds.refresh(buf)
          end)
        end)
        if not ok then
          session.gitsigns_base_state[buf] = nil
        end
      end)
    end, 100)
  end)
end

local function review_buffer(buf)
  local session = state.get()
  if not session or not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
    return false
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or not util.is_within(name, session.workspace) then
    return false
  end

  threads.apply(buf)
  if config.options.readonly then
    vim.bo[buf].readonly = true
    vim.bo[buf].modifiable = false
  end

  local maps = config.options.keymaps
  vim.keymap.set("n", maps.files, files.open, { buffer = buf, desc = "List PR changed files" })
  vim.keymap.set("n", maps.comment, M.comment, { buffer = buf, desc = "Add GitHub review comment" })
  vim.keymap.set("n", maps.reply, M.reply, { buffer = buf, desc = "Reply to GitHub review thread" })
  vim.keymap.set(
    "n",
    maps.resolve,
    M.toggle_resolved,
    { buffer = buf, desc = "Resolve/unresolve GitHub review thread" }
  )
  vim.keymap.set("n", maps.next_thread, function()
    threads.jump(1)
  end, { buffer = buf, desc = "Next GitHub review thread" })
  vim.keymap.set("n", maps.previous_thread, function()
    threads.jump(-1)
  end, { buffer = buf, desc = "Previous GitHub review thread" })
  vim.keymap.set("n", maps.refresh, M.refresh, { buffer = buf, desc = "Refresh GitHub review" })

  vim.defer_fn(function()
    if state.get() == session and vim.api.nvim_buf_is_valid(buf) then
      apply_gitsigns(buf)
    end
  end, 100)
  return true
end

local function setup_autocmds(session)
  session.augroup = vim.api.nvim_create_augroup("PRSession", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost" }, {
    group = session.augroup,
    callback = function(args)
      vim.schedule(function()
        review_buffer(args.buf)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = session.augroup,
    pattern = "GitSignsUpdate",
    callback = function(args)
      if args.buf then
        apply_gitsigns(args.buf)
      end
    end,
  })
end

local function first_file(session)
  for _, entry in ipairs(session.changed_files) do
    if entry.status ~= "D" then
      local path = vim.fs.joinpath(session.workspace, entry.path)
      if vim.uv.fs_stat(path) then
        return path
      end
    end
  end
end

local function launch(session)
  session.ready = false
  state.set(session)
  threads.index(session.threads)
  setup_autocmds(session)
  configure_gitsigns(session)

  vim.cmd.tabnew()
  session.tabpage = vim.api.nvim_get_current_tabpage()
  vim.cmd("tcd " .. vim.fn.fnameescape(session.workspace))

  local path = first_file(session)
  if path then
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    session.content_window = vim.api.nvim_get_current_win()
    review_buffer(vim.api.nvim_get_current_buf())
  end

  nvim_tree.open(session.workspace, session.changed_files)
  session.ready = true
  util.notify(("reviewing %s#%d — %s"):format(session.repo, session.number, session.pr.title))
end

local function fail(message)
  opening = false
  util.notify(message, vim.log.levels.ERROR)
end

function M.open(input)
  if opening then
    util.notify("a review is already opening", vim.log.levels.WARN)
    return
  end
  if state.active() then
    util.notify("close the current review with :PRClose first", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable("gh") ~= 1 or vim.fn.executable("git") ~= 1 then
    util.notify("both gh and git must be installed", vim.log.levels.ERROR)
    return
  end

  opening = true
  local launch_cwd = vim.fn.getcwd()
  workspace.current_root(launch_cwd, function(_, current_root)
    github.current_repo(current_root or launch_cwd, function(repo_err, current_repo)
      if repo_err then
        current_repo = nil
      end
      local target, parse_err = target_parser.parse(input, current_repo)
      if not target then
        fail(parse_err)
        return
      end
      github.pr(target.repo, target.number, function(pr_err, pr)
        if pr_err then
          fail(pr_err)
          return
        end
        workspace.prepare(target.repo, target.number, current_repo, current_root, function(worktree_err, worktree)
          if worktree_err then
            fail(worktree_err)
            return
          end
          workspace.changed_files(worktree, pr.baseRefOid, pr.headRefOid, function(files_err, files, changed_set)
            if files_err then
              fail(files_err)
              return
            end
            github.threads(target.repo, target.number, function(threads_err, review_threads, pull_request_id)
              if threads_err then
                fail(threads_err)
                return
              end
              opening = false
              launch({
                repo = target.repo,
                number = target.number,
                pr = pr,
                pull_request_id = pull_request_id,
                workspace = worktree,
                changed_files = files,
                changed_set = changed_set,
                threads = review_threads,
                launch_root = current_root or launch_cwd,
              })
            end)
          end)
        end)
      end)
    end)
  end)
end

function M.refresh()
  local session = state.get()
  if not session then
    util.notify("no active review", vim.log.levels.WARN)
    return
  end
  github.threads(session.repo, session.number, function(err, review_threads)
    if state.get() ~= session then
      return
    end
    if err then
      util.notify(err, vim.log.levels.ERROR)
      return
    end
    threads.index(review_threads)
    threads.apply_loaded()
    nvim_tree.reload()
    util.notify("review threads refreshed")
  end)
end

function M.reply()
  local session = state.get()
  if not session then
    return
  end
  threads.select(function(thread)
    local comments = thread.comments and thread.comments.nodes or {}
    local first = comments[1]
    if not first or not first.id then
      util.notify("thread has no reply target", vim.log.levels.ERROR)
      return
    end
    editor.open({
      title = "Reply — <C-s> to submit",
      on_submit = function(body)
        github.reply(session.repo, session.number, first.id, body, function(err)
          if state.get() ~= session then
            return
          end
          if err then
            util.notify(err, vim.log.levels.ERROR)
            return
          end
          util.notify("reply posted")
          M.refresh()
        end)
      end,
    })
  end)
end

function M.comment()
  local session = state.get()
  if not session then
    return
  end
  local relative = util.relative(vim.api.nvim_buf_get_name(0), session.workspace)
  if not relative then
    util.notify("current buffer is outside the review workspace", vim.log.levels.WARN)
    return
  end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  editor.open({
    title = ("Comment on %s:%d — <C-s> to submit"):format(relative, line),
    on_submit = function(body)
      github.comment(session.repo, session.number, session.pr.headRefOid, relative, line, body, function(err)
        if state.get() ~= session then
          return
        end
        if err then
          util.notify(err, vim.log.levels.ERROR)
          return
        end
        util.notify("comment posted")
        M.refresh()
      end)
    end,
  })
end

function M.toggle_resolved()
  local session = state.get()
  if not session then
    return
  end
  threads.select(function(thread)
    local resolved = not (thread.isResolved == true)
    github.set_resolved(thread.id, resolved, function(err, updated)
      if state.get() ~= session then
        return
      end
      if err then
        util.notify(err, vim.log.levels.ERROR)
        return
      end
      thread.isResolved = updated.isResolved
      threads.apply_loaded()
      util.notify(updated.isResolved and "thread resolved" or "thread unresolved")
    end)
  end)
end

function M.close()
  local session = state.get()
  if not session then
    util.notify("no active review", vim.log.levels.WARN)
    return
  end
  restore_gitsigns(session)
  if session.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, session.augroup)
  end
  state.clear()

  if session.tabpage and vim.api.nvim_tabpage_is_valid(session.tabpage) then
    if #vim.api.nvim_list_tabpages() == 1 then
      vim.cmd.tabnew()
    end
    vim.api.nvim_set_current_tabpage(session.tabpage)
    vim.cmd.tabclose()
  end

  nvim_tree.restore(session.launch_root)
  util.notify("review closed; cached workspace kept at " .. session.workspace)
end

return M
