local M = {}

function M.trim(value)
  return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.notify(message, level)
  vim.schedule(function()
    vim.notify("pr.nvim: " .. message, level or vim.log.levels.INFO)
  end)
end

function M.run(args, opts, callback)
  opts = opts or {}
  local command = vim.list_extend({}, args)
  vim.system(command, {
    cwd = opts.cwd,
    env = opts.env,
    text = true,
    stdin = opts.stdin,
  }, function(result)
    vim.schedule(function()
      if callback then
        local err
        if result.code ~= 0 then
          local stderr = result.stderr or ""
          err = M.trim(stderr ~= "" and stderr or result.stdout)
          if err == "" then
            err = ("command exited with code %d"):format(result.code)
          end
        end
        callback(err, result.stdout, result)
      end
    end)
  end)
end

function M.json(stdout)
  local ok, value = pcall(vim.json.decode, stdout or "")
  if not ok then
    return nil, value
  end
  return value
end

function M.normalize(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p")):gsub("/$", "")
end

function M.is_within(path, root)
  local normalized_path = M.normalize(path)
  local normalized_root = M.normalize(root)
  return normalized_path == normalized_root or normalized_path:sub(1, #normalized_root + 1) == normalized_root .. "/"
end

function M.relative(path, root)
  local normalized_path = M.normalize(path)
  local normalized_root = M.normalize(root)
  if not M.is_within(normalized_path, normalized_root) then
    return nil
  end
  if normalized_path == normalized_root then
    return ""
  end
  return normalized_path:sub(#normalized_root + 2)
end

function M.set_lines(buf, lines)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local was_modifiable = vim.bo[buf].modifiable
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = was_modifiable
end

function M.split_repo(repo)
  local owner, name = tostring(repo or ""):match("^([^/]+)/([^/]+)$")
  return owner, name
end

return M
