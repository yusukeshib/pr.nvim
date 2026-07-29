local target = require("pr.target")

local function same(expected, actual)
  assert(vim.deep_equal(expected, actual), ("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)))
end

same({ repo = "owner/repo", number = 123 }, target.parse("owner/repo/123"))
same({ repo = "owner/repo", number = 123 }, target.parse("owner/repo#123"))
same({ repo = "owner/repo", number = 123 }, target.parse("https://github.com/owner/repo/pull/123"))
same({ repo = "owner/current", number = 123 }, target.parse("123", "owner/current"))
same({ repo = "owner/other", number = 123 }, target.parse("other/123", "owner/current"))
same({ repo = "owner/other", number = 123 }, target.parse("other 123", "owner/current"))

local missing, err = target.parse("123")
assert(missing == nil and err:find("requires"))

print("target_spec: ok")
vim.cmd.qa()
