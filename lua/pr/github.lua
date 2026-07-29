local util = require("pr.util")

local M = {}

local THREADS_QUERY = [[
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id
      reviewThreads(first: 100) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id isResolved isOutdated line originalLine startLine originalStartLine diffSide path
          comments(first: 100) {
            nodes { id body createdAt author { login } }
          }
        }
      }
    }
  }
}
]]

local RESOLVE_MUTATION = [[
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) { thread { id isResolved } }
}
]]

local UNRESOLVE_MUTATION = [[
mutation($threadId: ID!) {
  unresolveReviewThread(input: {threadId: $threadId}) { thread { id isResolved } }
}
]]

local function graphql(query, variables, callback)
  local args = { "gh", "api", "graphql", "-f", "query=" .. query }
  for key, value in pairs(variables or {}) do
    local flag = type(value) == "number" and "-F" or "-f"
    vim.list_extend(args, { flag, key .. "=" .. tostring(value) })
  end
  util.run(args, {}, function(err, stdout)
    if err then
      callback(err)
      return
    end
    local decoded, decode_err = util.json(stdout)
    if not decoded then
      callback("invalid GitHub response: " .. tostring(decode_err))
      return
    end
    if decoded.errors and #decoded.errors > 0 then
      callback(decoded.errors[1].message or vim.inspect(decoded.errors))
      return
    end
    callback(nil, decoded)
  end)
end

function M.current_repo(cwd, callback)
  util.run(
    { "gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner" },
    { cwd = cwd },
    function(err, stdout)
      if err then
        callback(err)
        return
      end
      callback(nil, util.trim(stdout))
    end
  )
end

function M.pr(repo, number, callback)
  util.run({
    "gh",
    "pr",
    "view",
    tostring(number),
    "--repo",
    repo,
    "--json",
    table.concat({
      "id",
      "number",
      "title",
      "url",
      "baseRefName",
      "baseRefOid",
      "headRefName",
      "headRefOid",
      "isCrossRepository",
      "headRepository",
      "headRepositoryOwner",
    }, ","),
  }, {}, function(err, stdout)
    if err then
      callback(err)
      return
    end
    local decoded, decode_err = util.json(stdout)
    if not decoded then
      callback("invalid PR response: " .. tostring(decode_err))
      return
    end
    decoded.repo = repo
    callback(nil, decoded)
  end)
end

function M.threads(repo, number, callback)
  local owner, name = util.split_repo(repo)
  if not owner then
    callback("invalid repository: " .. tostring(repo))
    return
  end
  graphql(THREADS_QUERY, { owner = owner, name = name, number = number }, function(err, result)
    if err then
      callback(err)
      return
    end
    local pr = result.data and result.data.repository and result.data.repository.pullRequest
    if not pr then
      callback("pull request not found")
      return
    end
    local connection = pr.reviewThreads or {}
    if connection.pageInfo and connection.pageInfo.hasNextPage then
      util.notify("only the first 100 review threads are currently shown", vim.log.levels.WARN)
    end
    callback(nil, connection.nodes or {}, pr.id)
  end)
end

function M.reply(repo, number, comment_id, body, callback)
  local owner, name = util.split_repo(repo)
  util.run({
    "gh",
    "api",
    "-X",
    "POST",
    string.format("/repos/%s/%s/pulls/%d/comments/%s/replies", owner, name, number, comment_id),
    "-f",
    "body=" .. body,
  }, {}, function(err)
    callback(err)
  end)
end

function M.comment(repo, number, head_oid, path, line, body, callback)
  local owner, name = util.split_repo(repo)
  util.run({
    "gh",
    "api",
    "-X",
    "POST",
    string.format("/repos/%s/%s/pulls/%d/comments", owner, name, number),
    "-f",
    "body=" .. body,
    "-f",
    "commit_id=" .. head_oid,
    "-f",
    "path=" .. path,
    "-F",
    "line=" .. tostring(line),
    "-f",
    "side=RIGHT",
  }, {}, function(err)
    callback(err)
  end)
end

function M.set_resolved(thread_id, resolved, callback)
  local query = resolved and RESOLVE_MUTATION or UNRESOLVE_MUTATION
  local key = resolved and "resolveReviewThread" or "unresolveReviewThread"
  graphql(query, { threadId = thread_id }, function(err, result)
    if err then
      callback(err)
      return
    end
    local payload = result.data and result.data[key]
    if not payload or not payload.thread then
      callback("GitHub did not return the updated thread")
      return
    end
    callback(nil, payload.thread)
  end)
end

return M
