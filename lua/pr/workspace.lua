local config = require("pr.config")
local util = require("pr.util")

local M = {}

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function sanitize(value)
  return tostring(value):gsub("[^%w._-]", "-")
end

function M.path(repo, number)
  local owner, name = util.split_repo(repo)
  return vim.fs.joinpath(
    config.options.state_dir,
    "worktrees",
    sanitize(owner),
    sanitize(name),
    "pr-" .. tostring(number)
  )
end

local function checkout(path, repo, number, callback)
  util.run(
    { "gh", "pr", "checkout", tostring(number), "--repo", repo, "--detach", "--force" },
    { cwd = path },
    function(err)
      callback(err, path)
    end
  )
end

function M.prepare(repo, number, current_repo, current_root, callback)
  local path = M.path(repo, number)
  vim.fn.mkdir(vim.fs.dirname(path), "p")

  if exists(vim.fs.joinpath(path, ".git")) then
    checkout(path, repo, number, callback)
    return
  end

  if exists(path) then
    callback("workspace path exists but is not a git checkout: " .. path)
    return
  end

  if current_repo == repo and current_root then
    util.run({ "git", "worktree", "add", "--detach", path, "HEAD" }, { cwd = current_root }, function(err)
      if err then
        callback(err)
        return
      end
      checkout(path, repo, number, callback)
    end)
    return
  end

  util.run({ "gh", "repo", "clone", repo, path, "--", "--filter=blob:none" }, {}, function(err)
    if err then
      callback(err)
      return
    end
    checkout(path, repo, number, callback)
  end)
end

function M.changed_files(path, base_oid, head_oid, callback)
  util.run(
    { "git", "diff", "--name-status", "--find-renames", base_oid .. "..." .. head_oid },
    { cwd = path },
    function(err, stdout)
      if err then
        callback(err)
        return
      end
      local files = {}
      local set = {}
      for line in (stdout or ""):gmatch("[^\r\n]+") do
        local parts = vim.split(line, "\t", { plain = true })
        local status = parts[1]
        local old_path
        local file_path
        if status and status:sub(1, 1) == "R" then
          old_path = parts[2]
          file_path = parts[3]
        else
          file_path = parts[2]
        end
        if file_path then
          local entry = { status = status:sub(1, 1), path = file_path, old_path = old_path }
          table.insert(files, entry)
          set[file_path] = entry
        end
      end
      callback(nil, files, set)
    end
  )
end

function M.current_root(cwd, callback)
  util.run({ "git", "rev-parse", "--show-toplevel" }, { cwd = cwd }, function(err, stdout)
    if err then
      callback(err)
      return
    end
    callback(nil, util.trim(stdout))
  end)
end

return M
