local util = require("pr.util")

local M = {}

local function result(repo, number)
  number = tonumber(number)
  if not repo or not number or number < 1 then
    return nil
  end
  return { repo = repo, number = number }
end

function M.parse(input, current_repo)
  input = util.trim(input)
  if input == "" then
    return nil, "expected a PR number, owner/repo#number, owner/repo/number, or GitHub PR URL"
  end

  local owner, repo, number = input:match("^https?://github%.com/([^/]+)/([^/]+)/pull/(%d+)/?.*$")
  if owner then
    return result(owner .. "/" .. repo, number)
  end

  owner, repo, number = input:match("^([^/%s]+)/([^/#%s]+)#(%d+)$")
  if owner then
    return result(owner .. "/" .. repo, number)
  end

  owner, repo, number = input:match("^([^/%s]+)/([^/%s]+)/(%d+)$")
  if owner then
    return result(owner .. "/" .. repo, number)
  end

  local first, second = input:match("^([^/%s]+)/(%d+)$")
  if first and current_repo then
    owner = current_repo:match("^([^/]+)/")
    if owner then
      return result(owner .. "/" .. first, second)
    end
  end

  repo, number = input:match("^([^/%s]+)%s+(%d+)$")
  if repo and current_repo then
    owner = current_repo:match("^([^/]+)/")
    if owner then
      return result(owner .. "/" .. repo, number)
    end
  end

  if input:match("^%d+$") then
    if not current_repo then
      return nil, "a bare PR number requires running inside a GitHub repository"
    end
    return result(current_repo, input)
  end

  return nil, "invalid target: " .. input
end

return M
